import Hero from "./components/Hero";
import Features from "./components/Features";
import AppMockup from "./components/AppMockup";
import HowItWorks from "./components/HowItWorks";
import Installation from "./components/Installation";
import Footer from "./components/Footer";

export default function Home() {
  return (
    <main>
      <Hero />
      <Features />
      <AppMockup />
      <HowItWorks />
      <Installation />
      <Footer />
    </main>
  );
}
