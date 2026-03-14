import React from "react";
import { ProfileSection } from "../organisms/profile-section";

const SettingMain = () => {
  return (
    <div className="my-auto max-w-xl lg:max-w-2xl mx-auto flex flex-col items-center px-4">
      <div className="py-6">
        <h2 className="text-xl font-bold">Settings</h2>
      </div>
      <ProfileSection />
    </div>
  );
};

export default SettingMain;
