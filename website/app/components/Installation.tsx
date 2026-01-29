"use client";

import { useState } from "react";
import { Copy, Check } from "lucide-react";

const tabs = [
  {
    label: "Homebrew",
    code: "brew install Priyans-hu/tap/tokenmeter",
  },
  {
    label: "Script",
    code: "curl -fsSL https://raw.githubusercontent.com/Priyans-hu/tokenmeter/main/install.sh | bash",
  },
  {
    label: "Manual",
    code: `git clone https://github.com/Priyans-hu/tokenmeter.git
cd tokenmeter
swift build -c release`,
  },
];

export default function Installation() {
  const [activeTab, setActiveTab] = useState(0);
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(tabs[activeTab].code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <section id="installation" className="px-6 py-24 sm:py-32">
      <div className="mx-auto max-w-2xl">
        <h2 className="text-center text-3xl font-bold tracking-tight sm:text-4xl">
          Installation
        </h2>

        {/* Tabs */}
        <div className="mt-12 flex gap-1 border-b border-white/10">
          {tabs.map((tab, index) => (
            <button
              key={tab.label}
              onClick={() => {
                setActiveTab(index);
                setCopied(false);
              }}
              className={`relative px-4 py-2.5 text-sm font-medium transition-colors ${
                activeTab === index
                  ? "text-white"
                  : "text-gray-500 hover:text-gray-300"
              }`}
            >
              {tab.label}
              {activeTab === index && (
                <span className="absolute inset-x-0 -bottom-px h-0.5 bg-blue-500" />
              )}
            </button>
          ))}
        </div>

        {/* Code block */}
        <div className="relative mt-4 overflow-hidden rounded-lg border border-white/10 bg-[#111]">
          <div className="overflow-x-auto p-4 pr-14">
            <pre className="font-mono text-sm leading-relaxed text-gray-300">
              <code>{tabs[activeTab].code}</code>
            </pre>
          </div>

          {/* Copy button */}
          <button
            onClick={handleCopy}
            className="absolute top-3 right-3 rounded-md p-1.5 text-gray-500 transition-colors hover:bg-white/10 hover:text-white"
            aria-label="Copy code"
          >
            {copied ? (
              <Check className="h-4 w-4 text-green-400" />
            ) : (
              <Copy className="h-4 w-4" />
            )}
          </button>
        </div>
      </div>
    </section>
  );
}
