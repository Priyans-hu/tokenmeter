const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;
const { openUrl } = window.__TAURI__.opener;
const { getCurrentWindow, LogicalSize } = window.__TAURI__.window;

const WINDOW_WIDTH = 360;
const MAX_HEIGHT = 750;

const MODEL_COLORS = [
  '#6366f1', '#8b5cf6', '#a78bfa', '#c4b5fd',
  '#22c55e', '#eab308', '#ef4444', '#06b6d4',
];

// Estimated token limits (configurable later when API provides real data)
const SESSION_TOKEN_LIMIT = 1_000_000;
const WEEKLY_TOKEN_LIMIT = 5_000_000;

function shortModelName(name) {
  if (name.includes('opus')) return 'Opus';
  if (name.includes('sonnet')) return 'Sonnet';
  if (name.includes('haiku')) return 'Haiku';
  return name.replace('claude-', '').replace(/-\d+$/g, '');
}

function formatCost(cost) {
  if (cost >= 1000) return `$${(cost / 1000).toFixed(1)}k`;
  if (cost >= 100) return `$${cost.toFixed(0)}`;
  if (cost >= 10) return `$${cost.toFixed(1)}`;
  return `$${cost.toFixed(2)}`;
}

function formatTokens(tokens) {
  if (tokens >= 1_000_000) return `${(tokens / 1_000_000).toFixed(1)}M`;
  if (tokens >= 1_000) return `${(tokens / 1_000).toFixed(1)}k`;
  return `${tokens}`;
}

function formatResetTime(minutes, windowHours) {
  if (minutes == null) return '--';
  if (minutes <= 0) return 'now';
  if (windowHours >= 24) {
    const d = Math.floor(minutes / 1440);
    const h = Math.floor((minutes % 1440) / 60);
    if (d > 0) return `Resets in ${d}d ${h}h`;
    return `Resets in ${h}h`;
  }
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h > 0) return `Resets in ${h}h ${m}m`;
  return `Resets in ${m}m`;
}

function formatDate(dateStr) {
  const d = new Date(dateStr + 'T00:00:00');
  return d.toLocaleDateString('en', { month: 'short', day: 'numeric' });
}

function shortDay(dateStr) {
  const d = new Date(dateStr + 'T00:00:00');
  const wd = d.toLocaleDateString('en', { weekday: 'short' });
  return wd.substring(0, 2);
}

function timeAgo(dateStr) {
  const now = new Date();
  const then = new Date(dateStr);
  const diffMs = now - then;
  const mins = Math.floor(diffMs / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  return `${hrs}h ${mins % 60}m ago`;
}

const $ = (id) => document.getElementById(id);

let currentView = 'dashboard';
let lastDailyData = null;
let updateUrl = null;

// --- Window Resizing ---

function resizeWindow() {
  requestAnimationFrame(() => {
    const app = $('app');
    const height = Math.min(app.scrollHeight + 8, MAX_HEIGHT);
    getCurrentWindow().setSize(new LogicalSize(WINDOW_WIDTH, height));
  });
}

// --- Rendering ---

function renderDashboard(data) {
  $('loading').style.display = 'none';
  $('error').style.display = 'none';
  $('content').style.display = 'block';

  // Header updated time
  $('last-updated').textContent = timeAgo(data.lastUpdated);

  // Cost
  $('today-cost').textContent = formatCost(data.todayCost);
  $('today-tokens').textContent = data.todayTokens > 0 ? `${formatTokens(data.todayTokens)} tokens` : '';
  $('week-cost').textContent = formatCost(data.weekCost);
  $('month-cost').textContent = formatCost(data.monthCost);

  // Rate limits
  renderRateLimit('session', data.rateLimits.session, SESSION_TOKEN_LIMIT, true);
  renderRateLimit('weekly', data.rateLimits.weekly, WEEKLY_TOKEN_LIMIT, false);

  // Chart & breakdown
  lastDailyData = data.daily;
  const chartDays = parseInt($('chart-range').value || '7');
  renderDailyChart(data.daily, chartDays);
  renderModelBreakdown(data.todayModelBreakdowns);

  resizeWindow();
}

function renderRateLimit(prefix, windowInfo, limit, showPace) {
  if (!windowInfo) return;

  const tokens = windowInfo.tokensUsed || 0;
  const pct = Math.min((tokens / limit) * 100, 100);

  const fill = $(`${prefix}-fill`);
  fill.style.width = `${pct}%`;

  if (pct < 50) {
    fill.style.background = 'var(--green)';
  } else if (pct < 80) {
    fill.style.background = 'var(--yellow)';
  } else {
    fill.style.background = 'var(--red)';
  }

  $(`${prefix}-pct`).textContent = `${pct.toFixed(0)}% used`;
  $(`${prefix}-reset`).textContent = formatResetTime(windowInfo.minutesUntilReset, windowInfo.windowHours);

  if (showPace) {
    renderPace(windowInfo, limit);
  }
}

function renderPace(windowInfo, limit) {
  const paceEl = $('session-pace');
  if (!windowInfo.minutesUntilReset || windowInfo.tokensUsed === 0) {
    paceEl.textContent = '';
    paceEl.className = 'pace-line';
    return;
  }

  const windowMinutes = windowInfo.windowHours * 60;
  const elapsed = windowMinutes - windowInfo.minutesUntilReset;
  const elapsedFraction = elapsed / windowMinutes;
  const usageFraction = windowInfo.tokensUsed / limit;

  if (elapsedFraction <= 0) {
    paceEl.textContent = '';
    paceEl.className = 'pace-line';
    return;
  }

  const pace = usageFraction / elapsedFraction;
  const pctDiff = ((pace - 1) * 100).toFixed(0);

  if (pace < 0.85) {
    paceEl.textContent = `Behind (${pctDiff}%) \u00B7 Lasts to reset`;
    paceEl.className = 'pace-line pace-behind';
  } else if (pace <= 1.15) {
    paceEl.textContent = 'On track';
    paceEl.className = 'pace-line';
  } else if (pace <= 1.5) {
    paceEl.textContent = `Ahead (+${pctDiff}%) \u00B7 May deplete early`;
    paceEl.className = 'pace-line pace-ahead';
  } else {
    paceEl.textContent = `Ahead (+${pctDiff}%) \u00B7 May deplete early`;
    paceEl.className = 'pace-line pace-critical';
  }
}

function renderDailyChart(daily, days) {
  const container = $('daily-chart');
  container.innerHTML = '';

  if (!daily || daily.length === 0) {
    container.innerHTML = '<div class="no-data">No data yet</div>';
    return;
  }

  const sliced = daily.slice(-days);
  const maxCost = Math.max(...sliced.map(d => d.totalCost), 0.01);
  const chartHeight = 80;

  sliced.forEach(day => {
    const wrapper = document.createElement('div');
    wrapper.className = 'chart-bar-wrapper';

    const bar = document.createElement('div');
    bar.className = 'chart-bar';
    const pct = (day.totalCost / maxCost) * chartHeight;
    bar.style.height = `${Math.max(pct, 2)}px`;

    const tooltip = document.createElement('div');
    tooltip.className = 'chart-bar-tooltip';
    tooltip.textContent = `${formatDate(day.date)}: ${formatCost(day.totalCost)}`;
    bar.appendChild(tooltip);

    const label = document.createElement('div');
    label.className = 'chart-bar-label';
    label.textContent = shortDay(day.date);

    wrapper.appendChild(bar);
    wrapper.appendChild(label);
    container.appendChild(wrapper);
  });
}

function renderModelBreakdown(breakdowns) {
  const donut = $('donut');
  const legend = $('breakdown-legend');

  if (!breakdowns || breakdowns.length === 0) {
    donut.style.background = 'var(--bg-input)';
    legend.innerHTML = '<div class="no-data">No usage today</div>';
    return;
  }

  const total = breakdowns.reduce((sum, b) => sum + b.cost, 0);
  if (total === 0) {
    donut.style.background = 'var(--bg-input)';
    legend.innerHTML = '<div class="no-data">No cost data</div>';
    return;
  }

  let gradientParts = [];
  let cumPct = 0;
  breakdowns.forEach((b, i) => {
    const pct = (b.cost / total) * 100;
    const color = MODEL_COLORS[i % MODEL_COLORS.length];
    gradientParts.push(`${color} ${cumPct}% ${cumPct + pct}%`);
    cumPct += pct;
  });
  donut.style.background = `conic-gradient(${gradientParts.join(', ')})`;

  legend.innerHTML = '';
  breakdowns.forEach((b, i) => {
    const color = MODEL_COLORS[i % MODEL_COLORS.length];
    const pct = ((b.cost / total) * 100).toFixed(0);
    const item = document.createElement('div');
    item.className = 'legend-item';
    item.innerHTML = `
      <span class="legend-dot" style="background:${color}"></span>
      <span class="legend-name">${shortModelName(b.modelName)}</span>
      <span class="legend-cost">${formatCost(b.cost)} (${pct}%)</span>
    `;
    legend.appendChild(item);
  });
}

// --- Update Banner ---

async function checkForUpdates() {
  try {
    const result = await invoke('check_for_updates');
    if (result) {
      updateUrl = result.url;
      $('update-text').textContent = `v${result.version} available`;
      $('update-banner').style.display = 'flex';
      resizeWindow();
    }
  } catch (_) {
    // Silently fail — not critical
  }
}

// --- Error ---

function showError(msg) {
  $('loading').style.display = 'none';
  $('content').style.display = 'none';
  $('error').style.display = 'block';
  $('error').textContent = msg;
  resizeWindow();
}

// --- View Switching ---

function showDashboard() {
  currentView = 'dashboard';
  $('dashboard-view').style.display = 'block';
  $('settings-view').style.display = 'none';
  resizeWindow();
}

function showSettings() {
  currentView = 'settings';
  $('dashboard-view').style.display = 'none';
  $('settings-view').style.display = 'block';
  loadSettingsForm();
  resizeWindow();
}

function loadSettingsForm() {
  const config = JSON.parse(localStorage.getItem('config') || '{}');
  $('refresh-interval').value = config.refreshIntervalSecs || 300;
}

function saveSettings() {
  const config = {
    refreshIntervalSecs: parseInt($('refresh-interval').value),
  };
  localStorage.setItem('config', JSON.stringify(config));
  showDashboard();
  refreshData();
}

// --- Data Fetching ---

async function refreshData() {
  const btn = $('refresh-btn');
  btn.classList.add('spinning');
  try {
    const data = await invoke('refresh_usage');
    renderDashboard(data);
  } catch (e) {
    showError(e);
  } finally {
    btn.classList.remove('spinning');
  }
}

async function loadInitialData() {
  try {
    const data = await invoke('get_usage');
    renderDashboard(data);
  } catch (_) {
    // Data not ready yet, wait for usage-updated event
  }
}

// --- Init ---

async function init() {
  // Button handlers
  $('refresh-btn').addEventListener('click', refreshData);
  $('settings-btn').addEventListener('click', showSettings);
  $('back-btn').addEventListener('click', showDashboard);
  $('settings-form').addEventListener('submit', (e) => {
    e.preventDefault();
    saveSettings();
  });

  // Chart range selector
  $('chart-range').addEventListener('change', (e) => {
    if (lastDailyData) {
      renderDailyChart(lastDailyData, parseInt(e.target.value));
    }
  });

  // Update banner
  $('update-action').addEventListener('click', () => {
    if (updateUrl) openUrl(updateUrl);
  });
  $('update-dismiss').addEventListener('click', () => {
    $('update-banner').style.display = 'none';
    resizeWindow();
  });

  // Quick links
  $('link-dashboard').addEventListener('click', () => {
    openUrl('https://console.anthropic.com/settings/usage');
  });
  $('link-status').addEventListener('click', () => {
    openUrl('https://status.anthropic.com/');
  });

  // Events from backend
  await listen('usage-updated', (event) => {
    if (currentView === 'dashboard') {
      renderDashboard(event.payload);
    }
  });

  await listen('usage-error', (event) => {
    if (currentView === 'dashboard') {
      showError(event.payload);
    }
  });

  await listen('show-settings', () => {
    showSettings();
  });

  await listen('check-for-updates', () => {
    checkForUpdates();
  });

  // Load data
  loadInitialData();

  // Initial resize for loading state
  resizeWindow();

  // Check for updates on startup (delayed)
  setTimeout(checkForUpdates, 3000);
}

window.addEventListener('DOMContentLoaded', init);
