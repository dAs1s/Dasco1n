import Image from "next/image";
import React from "react";

type Props = {
  src?: string | null;
  alt?: string;
  width: number;
  height: number;
  className?: string;
  style?: React.CSSProperties;
  fallbackSrc?: string;
};

function looksLikeGif(url: string) {
  const u = url.toLowerCase();
  return u.endsWith(".gif") || u.startsWith("data:image/gif") || u.includes("format=gif");
}

export default function SmartImage({
  src,
  alt = "",
  width,
  height,
  className,
  style,
  fallbackSrc,
}: Props) {
  const [err, setErr] = React.useState(false);
  const finalSrc = (!src || err) ? (fallbackSrc || "") : src;

  if (!finalSrc) return null;

  if (looksLikeGif(finalSrc)) {
    // Use plain <img> so GIFs animate and aren’t “optimized” to static frames
    return (
      <img
        src={finalSrc}
        alt={alt}
        width={width}
        height={height}
        className={className}
        style={{ display: "block", ...style }}
        onError={() => setErr(true)}
        loading="lazy"
        decoding="async"
      />
    );
  }

  // Use Next/Image for non-GIFs (optimization + resizing)
  return (
    <Image
      src={finalSrc}
      alt={alt}
      width={width}
      height={height}
      className={className}
      style={style}
      onError={() => setErr(true)}
    />
  );
}
