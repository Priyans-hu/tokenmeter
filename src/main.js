const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;

const MODEL_COLORS = [
  '#6366f1', '#8b5cf6', '#a78bfa', '#c4b5fd',
  '#22c55e', '#eab308', '#ef4444', '#06b6d4',
];

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

function formatResetTime(minutes) {
  if (minutes == null) return '--';
  if (minutes <= 0) return 'now';
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
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

const $ = (id) => document.getElementById(id);

let currentView = 'dashboard';

// --- Rendering ---

function renderDashboard(data) {
  $('loading').style.display = 'none';
  $('error').style.display = 'none';
  $('content').style.display = 'block';

  $('today-cost').textContent = formatCost(data.todayCost);
  $('week-cost').textContent = formatCost(data.weekCost);
  $('month-cost').textContent = formatCost(data.monthCost);

  renderContextWindow(data.contextWindow);
  renderDailyChart(data.daily);
  renderModelBreakdown(data.todayModelBreakdowns);

  const updated = new Date(data.lastUpdated);
  $('last-updated').textContent = `Updated ${updated.toLocaleTimeString('en', { hour: '2-digit', minute: '2-digit' })}`;
}

function renderContextWindow(cw) {
  if (!cw) return;

  const tokens = cw.tokensUsed || 0;
  // Estimate: ~1M tokens for Opus 5h window (configurable later)
  const limit = 1_000_000;
  const pct = Math.min((tokens / limit) * 100, 100);

  $('cw-fill').style.width = `${pct}%`;
  // Color gradient: green → yellow → red
  if (pct < 50) {
    $('cw-fill').style.background = 'var(--green)';
  } else if (pct < 80) {
    $('cw-fill').style.background = 'var(--yellow)';
  } else {
    $('cw-fill').style.background = 'var(--red)';
  }

  $('cw-pct').textContent = `${pct.toFixed(0)}%`;
  $('cw-tokens').textContent = formatTokens(tokens);
  $('cw-sessions').textContent = cw.sessionsActive || 0;
  $('cw-reset').textContent = formatResetTime(cw.minutesUntilReset);
}

function renderDailyChart(daily) {
  const container = $('daily-chart');
  container.innerHTML = '';

  if (!daily || daily.length === 0) {
    container.innerHTML = '<div class="no-data">No data yet</div>';
    return;
  }

  const chartDays = parseInt(localStorage.getItem('chartDays') || '7');
  const sliced = daily.slice(-chartDays);
  const maxCost = Math.max(...sliced.map(d => d.totalCost), 1);
  const chartHeight = 100;

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

function showError(msg) {
  $('loading').style.display = 'none';
  $('content').style.display = 'none';
  $('error').style.display = 'block';
  $('error').textContent = msg;
}

// --- View Switching ---

function showDashboard() {
  currentView = 'dashboard';
  $('dashboard-view').style.display = 'block';
  $('settings-view').style.display = 'none';
}

function showSettings() {
  currentView = 'settings';
  $('dashboard-view').style.display = 'none';
  $('settings-view').style.display = 'block';
  loadSettingsForm();
}

function loadSettingsForm() {
  const config = JSON.parse(localStorage.getItem('config') || '{}');
  $('refresh-interval').value = config.refreshIntervalSecs || 300;
  $('chart-days').value = config.chartDays || 7;
}

function saveSettings() {
  const config = {
    refreshIntervalSecs: parseInt($('refresh-interval').value),
    chartDays: parseInt($('chart-days').value),
  };
  localStorage.setItem('config', JSON.stringify(config));
  localStorage.setItem('chartDays', config.chartDays);
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
  $('refresh-btn').addEventListener('click', refreshData);
  $('settings-btn').addEventListener('click', showSettings);
  $('back-btn').addEventListener('click', showDashboard);
  $('settings-form').addEventListener('submit', (e) => {
    e.preventDefault();
    saveSettings();
  });

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

  loadInitialData();
}

window.addEventListener('DOMContentLoaded', init);
