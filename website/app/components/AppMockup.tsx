"use client";

import { motion } from "framer-motion";
import { RefreshCw, Settings } from "lucide-react";

function HeatmapGrid() {
  // 7 columns (days) x 5 rows (time slots) with varying opacity
  const cells = [
    [0.1, 0.3, 0.0, 0.6, 0.2, 0.8, 0.1],
    [0.4, 0.7, 0.2, 0.9, 0.5, 0.3, 0.0],
    [0.2, 0.5, 0.8, 0.4, 0.7, 0.1, 0.3],
    [0.6, 0.1, 0.4, 0.3, 0.9, 0.6, 0.2],
    [0.0, 0.8, 0.3, 0.7, 0.1, 0.5, 0.4],
  ];

  return (
    <div className="flex flex-col gap-[3px]">
      {cells.map((row, i) => (
        <div key={i} className="flex gap-[3px]">
          {row.map((opacity, j) => (
            <div
              key={j}
              className="h-3 w-3 rounded-[2px]"
              style={{
                backgroundColor:
                  opacity === 0
                    ? "rgba(255,255,255,0.05)"
                    : `rgba(74, 222, 128, ${opacity})`,
              }}
            />
          ))}
        </div>
      ))}
    </div>
  );
}

export default function AppMockup() {
  return (
    <section className="px-6 py-24 sm:py-32">
      <div className="mx-auto flex max-w-6xl justify-center">
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          whileInView={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.6, ease: "easeOut" }}
          viewport={{ once: true, margin: "-100px" }}
          className="w-full max-w-sm"
        >
          {/* Window frame */}
          <div className="overflow-hidden rounded-xl border border-white/10 bg-[#1a1a1a] shadow-2xl shadow-blue-500/5">
            {/* Title bar */}
            <div className="flex items-center gap-2 border-b border-white/10 bg-[#222] px-4 py-2.5">
              <div className="flex gap-1.5">
                <div className="h-3 w-3 rounded-full bg-[#ff5f57]" />
                <div className="h-3 w-3 rounded-full bg-[#febc2e]" />
                <div className="h-3 w-3 rounded-full bg-[#28c840]" />
              </div>
            </div>

            {/* Popover content */}
            <div className="p-4">
              {/* Header */}
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-semibold text-white">
                    TokenMeter
                  </span>
                  <span className="rounded bg-blue-500/20 px-1.5 py-0.5 text-[10px] font-medium text-blue-400">
                    Pro
                  </span>
                </div>
                <div className="flex items-center gap-2 text-gray-500">
                  <span className="text-[10px]">just now</span>
                  <RefreshCw className="h-3 w-3" />
                  <Settings className="h-3 w-3" />
                </div>
              </div>

              {/* Rate limit bars */}
              <div className="mt-4 space-y-3">
                {/* Session bar */}
                <div>
                  <div className="flex items-center justify-between text-xs">
                    <span className="text-gray-400">5-Hour Session</span>
                    <span className="text-blue-400">42%</span>
                  </div>
                  <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-white/10">
                    <div
                      className="h-full rounded-full bg-blue-500"
                      style={{ width: "42%" }}
                    />
                  </div>
                </div>

                {/* Weekly bar */}
                <div>
                  <div className="flex items-center justify-between text-xs">
                    <span className="text-gray-400">Weekly (7 days)</span>
                    <span className="text-orange-400">67%</span>
                  </div>
                  <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-white/10">
                    <div
                      className="h-full rounded-full bg-orange-500"
                      style={{ width: "67%" }}
                    />
                  </div>
                </div>
              </div>

              {/* Heatmap */}
              <div className="mt-4 rounded-lg border border-white/5 bg-white/[0.02] p-3">
                <p className="mb-2 text-[10px] font-medium text-gray-500">
                  Activity (7 days)
                </p>
                <HeatmapGrid />
              </div>

              {/* Cost row */}
              <div className="mt-4 grid grid-cols-3 gap-2">
                <div className="rounded-lg bg-white/[0.03] p-2 text-center">
                  <p className="text-[10px] text-gray-500">Today</p>
                  <p className="text-sm font-semibold text-white">$94.82</p>
                </div>
                <div className="rounded-lg bg-white/[0.03] p-2 text-center">
                  <p className="text-[10px] text-gray-500">This Week</p>
                  <p className="text-sm font-semibold text-white">$295</p>
                </div>
                <div className="rounded-lg bg-white/[0.03] p-2 text-center">
                  <p className="text-[10px] text-gray-500">This Month</p>
                  <p className="text-sm font-semibold text-white">$1,340</p>
                </div>
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
