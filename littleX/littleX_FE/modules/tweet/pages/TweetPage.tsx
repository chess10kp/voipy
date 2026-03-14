"use client";

import React from "react";

import LeftTweetSideBar from "@/ds/molecules/left-tweet-sidebar";
import RightTweetSidebar from "@/ds/molecules/right-tweet-sidebar";
import MainFeed from "@/ds/molecules/tweet-main";
import CheckProfile from "@/ds/molecules/check-profile-dialog";
import { ProtectedRoute } from "@/ds/wrappers/prtoected-auth";
import {
  MobileNavBar,
  MobileBottomNav,
  MobileRightSidebar,
} from "@/ds/molecules/mobile-components";

import ResponsiveDashboardTemplate from "@/ds/templates/responsive-dashboard-template";
import { useDashboard } from "@/_core/hooks/useDashboard";

const TweetPage = () => {
  const {
    profile,
    userData,
    following,
    suggestions,
    isLoading,
    navMenu,
    currentTab,
    logout,
    handleSearch,
    handleFollow,
    handleUnfollow,
    feeds,
    searchResult,
    userTweets,
  } = useDashboard();
  // If profile not set up, show dialog
  if (profile?.user?.username === "") {
    return (
      <ProtectedRoute>
        <CheckProfile open={true} isLoading={isLoading} />
      </ProtectedRoute>
    );
  }

  return (
    <ProtectedRoute>
      <ResponsiveDashboardTemplate
        // Mobile components
        mobileNavBar={
          <MobileNavBar userData={userData} onSearchSubmit={handleSearch} />
        }
        mobileBottomNav={<MobileBottomNav />}
        mobileRightSidebar={
          <MobileRightSidebar
            userData={userData}
            following={following}
            suggestions={suggestions}
            onFollow={handleFollow}
            onUnfollow={handleUnfollow}
          />
        }
        // Desktop components
        leftSidebar={
          <LeftTweetSideBar
            logout={logout}
            userData={userData}
            navMenu={navMenu}
            currentRoute={`/?tab=${currentTab}`}
          />
        }
        main={
          <MainFeed
            feeds={feeds}
            userTweets={userTweets}
            searchResult={searchResult}
            profile={profile.user}
            isLoading={isLoading}
          />
        }
        rightSidebar={
          <RightTweetSidebar
            userData={userData}
            following={following}
            suggetions={suggestions}
          />
        }
        sidebarWidth="w-72"
      />
    </ProtectedRoute>
  );
};

export default TweetPage;
