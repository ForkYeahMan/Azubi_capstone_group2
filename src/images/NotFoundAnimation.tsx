"use client";
import React, { useEffect, useRef } from "react";
import lottie from "lottie-web";

type Props = {
  path?: string;
  width?: number | string;
  height?: number | string;
  loop?: boolean;
  autoplay?: boolean;
};

export default function NotFoundAnimation({
  path = "/images/not-found.json",
  width = 300,
  height = 300,
  loop = true,
  autoplay = true,
}: Props) {
  const container = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!container.current) return;
    const anim = lottie.loadAnimation({
      container: container.current,
      renderer: "svg",
      loop,
      autoplay,
      path,
    });
    return () => anim.destroy();
  }, [path, loop, autoplay]);

  return <div ref={container} style={{ width, height }} />;
}
