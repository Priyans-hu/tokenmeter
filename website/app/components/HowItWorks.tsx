"use client";

import { useRef } from "react";
import { motion, useInView } from "framer-motion";
import { Terminal, Shield, Zap } from "lucide-react";

const steps = [
  {
    icon: Terminal,
    title: "Install",
    description:
      "One command via Homebrew or curl. No Xcode required.",
  },
  {
    icon: Shield,
    title: "Authorize",
    description:
      'Allow Keychain access on first launch. Click "Always Allow" \u2014 one time only.',
  },
  {
    icon: Zap,
    title: "Track",
    description:
      "TokenMeter appears in your menu bar. Real-time usage data, always one click away.",
  },
];

const containerVariants = {
  hidden: {},
  visible: {
    transition: {
      staggerChildren: 0.15,
    },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.5, ease: "easeOut" },
  },
};

export default function HowItWorks() {
  const ref = useRef<HTMLDivElement>(null);
  const isInView = useInView(ref, { once: true, margin: "-100px" });

  return (
    <section className="px-6 py-24 sm:py-32">
      <div className="mx-auto max-w-4xl">
        <h2 className="text-center text-3xl font-bold tracking-tight sm:text-4xl">
          Get started in seconds
        </h2>

        <motion.div
          ref={ref}
          variants={containerVariants}
          initial="hidden"
          animate={isInView ? "visible" : "hidden"}
          className="relative mt-16 grid grid-cols-1 gap-12 md:grid-cols-3 md:gap-8"
        >
          {/* Dashed connector lines (hidden on mobile) */}
          <div className="pointer-events-none absolute top-10 right-1/3 left-1/3 hidden h-px border-t border-dashed border-white/20 md:block" />

          {steps.map((step, index) => (
            <motion.div
              key={step.title}
              variants={itemVariants}
              className="relative flex flex-col items-center text-center"
            >
              {/* Step number */}
              <div className="absolute -top-3 right-0 left-0 flex justify-center md:static md:mb-0">
                <span className="text-xs font-medium text-gray-600">
                  Step {index + 1}
                </span>
              </div>

              {/* Icon circle */}
              <div className="relative z-10 mt-4 flex h-20 w-20 items-center justify-center rounded-full border border-white/10 bg-[#111]">
                <step.icon className="h-8 w-8 text-blue-400" />
              </div>

              <h3 className="mt-5 text-lg font-semibold">{step.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-gray-400">
                {step.description}
              </p>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
