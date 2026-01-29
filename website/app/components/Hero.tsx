"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { Copy, Check, ExternalLink, Download } from "lucide-react";

export default function Hero() {
  const [copied, setCopied] = useState(false);
  const installCmd = "brew install Priyans-hu/tap/tokenmeter";

  const handleCopy = async () => {
    await navigator.clipboard.writeText(installCmd);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <section className="relative overflow-hidden px-6 pt-32 pb-24 sm:pt-40 sm:pb-32">
      {/* Background glow */}
      <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
        <div className="h-[600px] w-[600px] rounded-full bg-blue-500/10 blur-[120px]" />
      </div>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, ease: "easeOut" }}
        className="relative mx-auto max-w-3xl text-center"
      >
        <h1 className="text-5xl font-bold tracking-tight sm:text-7xl">
          <span className="bg-gradient-to-r from-blue-400 to-purple-500 bg-clip-text text-transparent">
            Track your Claude Code usage
          </span>
        </h1>

        <p className="mx-auto mt-6 max-w-2xl text-lg leading-relaxed text-gray-400 sm:text-xl">
          Real-time rate limits, cost analytics, and usage heatmaps — right in
          your macOS menu bar.
        </p>

        {/* Install command */}
        <div className="mx-auto mt-10 flex max-w-xl items-center gap-2 rounded-lg border border-white/10 bg-white/5 px-4 py-3 font-mono text-sm">
          <span className="text-gray-500">$</span>
          <span className="flex-1 text-left text-gray-300">{installCmd}</span>
          <button
            onClick={handleCopy}
            className="flex items-center gap-1.5 rounded-md px-2 py-1 text-gray-400 transition-colors hover:bg-white/10 hover:text-white"
            aria-label="Copy install command"
          >
            {copied ? (
              <Check className="h-4 w-4 text-green-400" />
            ) : (
              <Copy className="h-4 w-4" />
            )}
          </button>
        </div>

        {/* CTA buttons */}
        <div className="mt-8 flex flex-wrap items-center justify-center gap-4">
          <a
            href="https://github.com/Priyans-hu/tokenmeter"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-lg border border-white/10 bg-white/5 px-6 py-3 text-sm font-medium text-white transition-colors hover:bg-white/10"
          >
            <ExternalLink className="h-4 w-4" />
            View on GitHub
          </a>
          <a
            href="https://github.com/Priyans-hu/tokenmeter/releases/latest"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-6 py-3 text-sm font-medium text-white transition-colors hover:bg-blue-500"
          >
            <Download className="h-4 w-4" />
            Download
          </a>
        </div>
      </motion.div>
    </section>
  );
}
