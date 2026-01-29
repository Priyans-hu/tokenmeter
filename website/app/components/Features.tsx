"use client";

import { useRef } from "react";
import { motion, useInView } from "framer-motion";
import {
  Activity,
  Bell,
  BarChart3,
  DollarSign,
  PieChart,
  Monitor,
} from "lucide-react";

const features = [
  {
    icon: Activity,
    title: "Real Rate Limits",
    description:
      "Live utilization percentages from Anthropic API. Session and weekly windows with reset countdowns.",
  },
  {
    icon: Bell,
    title: "Smart Notifications",
    description:
      "macOS alerts when you hit 80% of your rate limit. Throttled to avoid spam.",
  },
  {
    icon: BarChart3,
    title: "Usage Heatmap",
    description:
      "Hour-by-day activity grid showing your coding patterns over 7, 14, or 30 days.",
  },
  {
    icon: DollarSign,
    title: "Cost Tracking",
    description:
      "API-equivalent cost breakdown — today, this week, this month. Per-model pricing.",
  },
  {
    icon: PieChart,
    title: "Model Breakdown",
    description:
      "See which models you use most. Opus, Sonnet, Haiku — tokens and costs per model.",
  },
  {
    icon: Monitor,
    title: "Menu Bar Native",
    description:
      "Lives in your menu bar. No dock icon. Works in fullscreen. Auto-refreshes every 5 minutes.",
  },
];

const containerVariants = {
  hidden: {},
  visible: {
    transition: {
      staggerChildren: 0.1,
    },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 24 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.5, ease: "easeOut" },
  },
};

export default function Features() {
  const ref = useRef<HTMLDivElement>(null);
  const isInView = useInView(ref, { once: true, margin: "-100px" });

  return (
    <section className="px-6 py-24 sm:py-32">
      <div className="mx-auto max-w-6xl">
        <h2 className="text-center text-3xl font-bold tracking-tight sm:text-4xl">
          Everything you need
        </h2>

        <motion.div
          ref={ref}
          variants={containerVariants}
          initial="hidden"
          animate={isInView ? "visible" : "hidden"}
          className="mt-16 grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3"
        >
          {features.map((feature) => (
            <motion.div
              key={feature.title}
              variants={itemVariants}
              className="rounded-xl border border-white/10 bg-white/[0.03] p-6 transition-colors hover:border-white/20 hover:bg-white/[0.05]"
            >
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-blue-500/10">
                <feature.icon className="h-5 w-5 text-blue-400" />
              </div>
              <h3 className="mt-4 text-lg font-semibold">{feature.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-gray-400">
                {feature.description}
              </p>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
