import:py os;
import:py logging;
import:py datetime;
import:py from jac_cloud.core.architype { NodeAnchor }
import:py from mtllm.llms { OpenAI }

with entry {
    os.environ["OPEN_API_KEY"] = "PUT_KEY_HERE";
}

glob logger = logging.getLogger("littleX");

# Define nodes
node profile {
    has username: str = "";
    has followees: list = [];
}

node tweet {
    has content: str;
    has created_at: str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S");
}

# Define Edges
edge follow {}

edge post {}

# Add Meaning-type LLM
glob llm = OpenAI(model_name="gpt-4o-mini");
can 'Summarize what users are talking about in their latest trends, major events, and notable interactions from the recent tweets in one sentence.'
summarise_tweets(tweets: list[str]) -> 'Summarisation': str by llm();

# Define Walkers

# Profile
walker visit_profile {
    can visit_profile with `root entry {
        visit [-->(`?profile)] else {
            new_profile = here ++> profile();
            Jac.unrestrict(new_profile[0], level="READ");
            visit new_profile;
        }
    }
}

# Tweets
walker create_tweet :visit_profile: {
    has content: str;

    can tweet with profile entry {
        tweet_node = here +:post:+> tweet(content=self.content);
        visit tweet_node;
    }

    can report_tweet with tweet entry {
        Jac.unrestrict(here, level="READ");
        report here;
    }
}

walker load_tweets :visit_profile: {
    has tweets: list = [];

    can go_to_tweet with profile entry {
        visit [-->](`?tweet);
    }

    can load_tweets with tweet entry {
        Jac.unrestrict(here, level="READ");
        username = [<-:post:-][0].username;
        tweet_info = {"tweet": {"content": here, "username": username}};
        self.tweets.append(tweet_info);
    }
}

walker load_feed :visit_profile: {
    can load with profile entry {
        self.feeds: list = [];
        user_tweets = here spawn load_tweets();
        self.feeds.extend(user_tweets.tweets);
        
        for user in here.followees {
            user_node = &user;
            user_tweets = user_node spawn load_tweets();
            self.feeds.extend(user_tweets.tweets);
        }
        tweets = [feed['tweet']["content"].content for feed in self.feeds];
        self.summary: str = summarise_tweets(tweets);

        report {"feeds": self.feeds, "summary": self.summary};
    }
}

# Follow
walker follow_request :visit_profile: {
    has profile_id: str;

    can follow with profile entry {
        here.followees.append(self.profile_id);
        here +:follow():+> &self.profile_id;
        report here;
    }
}

### DO NOT MODIFY BELOW THIS LINE
### Boilerplate code for littleX ###

walker update_profile :visit_profile: {
    has new_username: str;

    can update_profile with profile entry {
        here.username = self.new_username;
        report here;
    }
}

walker get_profile :visit_profile: {
    can get_profile with profile entry {
        report here;
    }
}
walker load_user_profiles {
    obj __specs__ {
        static has auth: bool = False;
    }
    can load_profiles with `root entry {
        self.profiles: list = [];
        
        for user in NodeAnchor.Collection.find({"name": "profile"}) {
            user_node = user.architype;
            self.profiles.append(
                {"name": user_node.username, "id": jid(user_node)}
            );
        }
        report self.profiles;
    }
}


walker un_follow_request :visit_profile: {
    has profile_id: str;

    can un_follow with profile entry {
        here.followees.remove(self.profile_id);
        logger.info(f"Followe removed: {self.profile_id}");
        here del-:follow:-> &self.profile_id;
        report here;
    }
}

walker update_tweet :visit_profile: {
    has tweet_id: str;
    has updated_content: str;

    can visit_tweet with profile entry {
        tweet_node = &self.tweet_id;
        visit tweet_node;
        logger.info(f"Tweet deleted: {tweet_node}");
    }
    # can be enhanced to directly use the jid instead
    can update_tweet with tweet entry {
        here.content = self.updated_content;
        report here;
    }
}

walker remove_tweet :visit_profile: {
    has tweet_id: str;

    can remove_tweet with profile entry {
        tweet_node = &self.tweet_id;
        del tweet_node;
        logger.info(f"Tweet deleted: {tweet_node}");
        report True;
    }
}
