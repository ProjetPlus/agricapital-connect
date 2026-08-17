import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { Download, Smartphone, Wifi, WifiOff, Battery, Zap } from 'lucide-react';

interface BeforeInstallPromptEvent extends Event {
  prompt(): Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
}

const InstallPrompt = () => {
  const [deferredPrompt, setDeferredPrompt] = useState<BeforeInstallPromptEvent | null>(null);
  const [showPrompt, setShowPrompt] = useState(false);
  const [isIOS, setIsIOS] = useState(false);
  const [isPWAInstalled, setIsPWAInstalled] = useState(false);

  useEffect(() => {
    // Check if PWA is already installed
    const isStandalone = window.matchMedia('(display-mode: standalone)').matches 
      || (window.navigator as any).standalone === true;
    setIsPWAInstalled(isStandalone);
    if (isStandalone) return;

    // Background detection: periodically check if app is not installed
    const checkInterval = setInterval(() => {
      const stillNotInstalled = !window.matchMedia('(display-mode: standalone)').matches 
        && !(window.navigator as any).standalone;
      if (!stillNotInstalled) {
        setIsPWAInstalled(true);
        setShowPrompt(false);
        clearInterval(checkInterval);
      }
    }, 30000); // Check every 30s

    const isIOSDevice = /iPad|iPhone|iPod/.test(navigator.userAgent);
    setIsIOS(isIOSDevice);

    const shouldShowPrompt = () => {
      const dismissed = localStorage.getItem('pwa-install-dismissed-crm');
      const lastDismissed = dismissed ? parseInt(dismissed) : 0;
      const threeDaysAgo = Date.now() - (3 * 24 * 60 * 60 * 1000);
      return !dismissed || lastDismissed < threeDaysAgo;
    };

    const handleBeforeInstall = (e: Event) => {
      e.preventDefault();
      setDeferredPrompt(e as BeforeInstallPromptEvent);
      if (shouldShowPrompt()) {
        setTimeout(() => setShowPrompt(true), 2000);
      }
    };

    window.addEventListener('beforeinstallprompt', handleBeforeInstall);

    // iOS: also prompt installation
    if (isIOSDevice && !isStandalone && shouldShowPrompt()) {
      setTimeout(() => setShowPrompt(true), 3000);
    }

    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstall);
      clearInterval(checkInterval);
    };
  }, []);

  const handleInstall = async () => {
    if (!deferredPrompt) return;
    deferredPrompt.prompt();
    const { outcome } = await deferredPrompt.userChoice;
    if (outcome === 'accepted') {
      setIsPWAInstalled(true);
    }
    setDeferredPrompt(null);
    setShowPrompt(false);
  };

  const handleDismiss = () => {
    setShowPrompt(false);
    localStorage.setItem('pwa-install-dismissed-crm', Date.now().toString());
  };

  if (!showPrompt || isPWAInstalled) return null;

  return (
    <Dialog open={showPrompt} onOpenChange={setShowPrompt}>
      <DialogContent className="max-w-md mx-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-3 text-lg">
            <div className="p-3 bg-primary/10 rounded-xl">
              <Smartphone className="h-7 w-7 text-primary" />
            </div>
            <div>
              <span className="block">Installer AgriCapital CRM</span>
              <span className="text-sm font-normal text-muted-foreground">Application officielle</span>
            </div>
          </DialogTitle>
          <DialogDescription asChild>
            <div className="space-y-4 mt-4">
              {isIOS ? (
                <div className="space-y-3">
                  <p className="text-foreground font-medium">Pour installer sur votre iPhone/iPad :</p>
                  <ol className="list-decimal list-inside space-y-2 text-sm">
                    <li>Appuyez sur le bouton <strong>Partager</strong> ⬆️ en bas de Safari</li>
                    <li>Faites défiler et sélectionnez <strong>"Sur l'écran d'accueil"</strong></li>
                    <li>Appuyez sur <strong>Ajouter</strong></li>
                  </ol>
                </div>
              ) : (
                <p>Accédez à AgriCapital CRM directement depuis votre écran d'accueil pour une expérience optimale.</p>
              )}
              
              <div className="grid grid-cols-3 gap-3 pt-2">
                <div className="flex flex-col items-center gap-1.5 p-3 bg-muted rounded-lg">
                  <WifiOff className="h-5 w-5 text-primary" />
                  <span className="text-xs text-center font-medium">Mode hors ligne</span>
                </div>
                <div className="flex flex-col items-center gap-1.5 p-3 bg-muted rounded-lg">
                  <Zap className="h-5 w-5 text-primary" />
                  <span className="text-xs text-center font-medium">Plus rapide</span>
                </div>
                <div className="flex flex-col items-center gap-1.5 p-3 bg-muted rounded-lg">
                  <Battery className="h-5 w-5 text-primary" />
                  <span className="text-xs text-center font-medium">Notifications</span>
                </div>
              </div>
            </div>
          </DialogDescription>
        </DialogHeader>
        <div className="flex flex-col gap-3 mt-4">
          {!isIOS && deferredPrompt && (
            <Button onClick={handleInstall} size="lg" className="w-full gap-2">
              <Download className="h-5 w-5" />
              Installer maintenant
            </Button>
          )}
          <Button variant="outline" onClick={handleDismiss} className="w-full">
            Plus tard
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default InstallPrompt;
