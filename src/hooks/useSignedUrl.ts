import { useEffect, useState } from "react";
import { resolveStorageUrl } from "@/utils/storage";

/**
 * Resolves a stored storage path (or legacy full URL) to a fresh short-lived
 * signed URL at display time. Returns null while resolving or on error.
 */
export const useSignedUrl = (
  bucket: string,
  value: string | null | undefined,
  expiresIn = 3600
): string | null => {
  const [url, setUrl] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    if (!value) {
      setUrl(null);
      return;
    }
    resolveStorageUrl(bucket, value, expiresIn).then((resolved) => {
      if (!cancelled) setUrl(resolved);
    });
    return () => {
      cancelled = true;
    };
  }, [bucket, value, expiresIn]);

  return url;
};
