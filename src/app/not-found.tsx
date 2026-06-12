import { Button } from "@/components/Button";
import Link from "next/link";
import { siteConfig } from "./siteConfig";
import NotFoundAnimation from "@/images/NotFoundAnimation";

export default function NotFound() {
  return (
    <div className="flex h-screen flex-col items-center justify-center">
      <NotFoundAnimation width={300} height={300} />
      <Button asChild className="group mt-8" variant="light">
        <Link href={siteConfig.baseLinks.home}>Go to the home page</Link>
      </Button>
    </div>
  );
}
