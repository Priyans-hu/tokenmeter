export default function Footer() {
  return (
    <footer className="border-t border-white/10 px-6 py-10">
      <div className="mx-auto flex max-w-6xl flex-col items-center gap-6 sm:flex-row sm:justify-between">
        <div className="flex items-center gap-4">
          <span className="text-sm font-semibold text-white">TokenMeter</span>
          <span className="text-xs text-gray-600">MIT License</span>
        </div>

        <nav className="flex items-center gap-6">
          <a
            href="https://github.com/Priyans-hu/tokenmeter"
            target="_blank"
            rel="noopener noreferrer"
            className="text-xs text-gray-500 transition-colors hover:text-white"
          >
            GitHub
          </a>
          <a
            href="https://github.com/Priyans-hu/tokenmeter/releases"
            target="_blank"
            rel="noopener noreferrer"
            className="text-xs text-gray-500 transition-colors hover:text-white"
          >
            Releases
          </a>
          <a
            href="https://github.com/Priyans-hu/tokenmeter/issues"
            target="_blank"
            rel="noopener noreferrer"
            className="text-xs text-gray-500 transition-colors hover:text-white"
          >
            Issues
          </a>
        </nav>

        <p className="text-xs text-gray-600">
          Built by{" "}
          <a
            href="https://github.com/Priyans-hu"
            target="_blank"
            rel="noopener noreferrer"
            className="text-gray-400 transition-colors hover:text-white"
          >
            Priyanshu
          </a>
        </p>
      </div>
    </footer>
  );
}
