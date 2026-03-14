// import { TweetPage } from "@/modules/tweet/pages/TweetPage";

import TweetPage from "@/modules/tweet/pages/TweetPage";
import { Metadata } from "next";
export const metadata: Metadata = {
  title: "Little X",
  description: "Welcome to Little X",
};
export default function Home() {
  return <TweetPage />;
}
