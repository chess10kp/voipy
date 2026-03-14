import SettingsPage from "@/modules/settings/pages/SettingsPage";
import { Metadata } from "next";

export const metadata: Metadata = {
  title: "Settings | Little X",
  description: "Manage your Little X settings.",
};

const Settings = () => {
  return <SettingsPage />;
};

export default Settings;
