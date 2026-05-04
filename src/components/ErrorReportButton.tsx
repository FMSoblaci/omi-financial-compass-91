import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Bug } from "lucide-react";
import { ErrorReportDialog } from "./ErrorReportDialog";
import { toPng } from "html-to-image";
import { useToast } from "@/hooks/use-toast";

export const ErrorReportButton = () => {
  const { toast } = useToast();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [screenshot, setScreenshot] = useState<string | null>(null);
  const [isCapturing, setIsCapturing] = useState(false);

  const captureScreenshot = async () => {
    setIsCapturing(true);
    try {
      const dataUrl = await toPng(document.body, {
        cacheBust: true,
        pixelRatio: 1,
        backgroundColor: "#ffffff",
        filter: (node) => {
          const el = node as HTMLElement;
          if (!el?.classList) return true;
          return !el.classList.contains("error-report-button-ignore");
        },
      });

      if (dataUrl && dataUrl.length > 1000) {
        setScreenshot(dataUrl);
      } else {
        console.error("Screenshot data URL is too short or empty");
        setScreenshot(null);
      }
      setDialogOpen(true);
    } catch (error) {
      console.error("Error capturing screenshot:", error);
      toast({
        title: "Nie udało się zrobić screenshota",
        description: "Możesz zgłosić błąd bez zrzutu ekranu.",
        variant: "destructive",
      });
      setScreenshot(null);
      setDialogOpen(true);
    } finally {
      setIsCapturing(false);
    }
  };

  const getBrowserInfo = () => {
    return {
      userAgent: navigator.userAgent,
      language: navigator.language,
      platform: navigator.platform,
      screenWidth: window.screen.width,
      screenHeight: window.screen.height,
      windowWidth: window.innerWidth,
      windowHeight: window.innerHeight,
    };
  };

  return (
    <>
      <Button
        onClick={captureScreenshot}
        disabled={isCapturing}
        variant="outline"
        size="sm"
        title="Zgłoś błąd"
      >
        <Bug className="h-4 w-4 mr-1" />
        {isCapturing ? "..." : "Zgłoś błąd"}
      </Button>

      <ErrorReportDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        autoScreenshot={screenshot}
        pageUrl={window.location.href}
        browserInfo={getBrowserInfo()}
      />
    </>
  );
};
