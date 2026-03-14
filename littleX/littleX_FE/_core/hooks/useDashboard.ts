"use client";

import useAppNavigation from "@/_core/hooks/useAppNavigation";
import {
  fetchTweetsAction,
  followRequestAction,
  searchTweetsAction,
  unFollowRequestAction,
  useTweets,
} from "@/modules/tweet";
import { useAuth } from "@/modules/users/hooks/use-auth";
import { useAppDispatch } from "@/store/useStore";
import { useMemo } from "react";

export type NavMenu = {
  id: number;
  name: "Home" | "My Tweets" | "Settings"; // Limited to known menu items

  route: string; // Changed from 'param' to 'route' for clarity
  count?: number; // Made optional since not all menu items need counts
  isActive?: boolean; // Add active state
};
export const useDashboard = () => {
  const {
    profile,
    userProfiles,
    items: feeds,
    isLoading,
    searchResult,
  } = useTweets();
  const { data, logout } = useAuth();
  const dispatch = useAppDispatch();
  const navigation = useAppNavigation();
  const currentTab = navigation.getQueryParams().tab || "home";
  const currentPath = navigation.getCurrentPath();

  const userData = {
    username: profile?.user?.username || "",
    email: data?.email || "",
  };

  const following = profile?.following || [];
  const suggestions = userProfiles;
  const userTweets = feeds.filter(
    (item) => item.username === userData.username
  );

  // Navigation menu for main dashboard
  const navMenu: NavMenu[] = useMemo(
    () => [
      {
        id: 1,
        name: "Home",
        route: "/?tab=home",
        count: feeds.length,
        isActive: currentTab === "home",
      },
      {
        id: 2,
        name: "My Tweets",
        route: "/?tab=profile",
        count: userTweets.length,
        isActive: currentTab === "profile",
      },
      {
        id: 3,
        name: "Settings",
        route: "/settings",
        count: 0,
        isActive: currentPath.includes("settings"),
      },
    ],
    [feeds.length, userTweets.length, currentTab, currentPath]
  );

  // Handle search from any component
  const handleSearch = (query: string) => {
    navigation.navigate("/?tab=search");
    dispatch(searchTweetsAction(query));
  };

  // Handle follow/unfollow actions
  const handleFollow = (id: string) => {
    dispatch(followRequestAction(id));
    dispatch(fetchTweetsAction());
  };

  const handleUnfollow = (id: string) => {
    dispatch(unFollowRequestAction(id));
    dispatch(fetchTweetsAction());
  };

  return {
    // Data
    profile,
    userData,
    following,
    suggestions,
    userTweets,
    feeds,
    isLoading,
    navMenu,
    currentTab,
    searchResult,

    // Methods
    logout,
    handleSearch,
    handleFollow,
    handleUnfollow,
  };
};
