import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "TokenMeter - Claude Code Usage Tracker",
  description:
    "macOS menu bar app for tracking Claude Code usage, rate limits, and costs",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={inter.className}>
      <body className="bg-[#0a0a0a] text-white antialiased">{children}</body>
    </html>
  );
}
