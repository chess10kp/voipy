import:py from sentence_transformers { SentenceTransformer, util }
import:py base64;
node Hastag_node {}

can config_server() {
    import:py from jac_cloud { FastAPI }
    import:py from fastapi.middleware.cors { CORSMiddleware }
    FastAPI.get().add_middleware(
        CORSMiddleware,
        allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"]
    );
    FastAPI.enable();
}

with entry:__main__ {
    config_server();
}

obj Feed_node {
    has count_tag: dict = {};
    has total_count: int = 0;

    can update_count(tag: str) {
        self.count_tag[tag] = self.count_tag.get(tag, 0) + 1;
        self.total_count += 1;
    }

    can get_feed(feed_count: int=5) {
        if self.total_count <= feed_count {
            return self.count_tag;
        }
        scale_factor = feed_count / self.total_count;
        feed = {key: round(value * scale_factor)  for (key, value) in self.count_tag.items()};
        diff = self.total_count - feed_count;
        for key in feed {
            if diff == 0 {
                disengage;
            }
            feed[key] += 1 if diff > 0 else -1;
            diff += -1 if diff > 0 else 1;
        }
        return feed;
    }
}

node Tweet_main {}

node Tweet_node {}

node Tweet {
    has content: str;
    has tag: str;
    has embedding: str;
}

node Comment {
    has content: str;
    has embedding: str;
}

edge Hastag {
    has tag: str;
}

edge Following {}

edge Tweeting {}

edge Reply {}

edge Like {}

glob model:SentenceTransformer = SentenceTransformer(
    'sentence-transformers/multi-qa-mpnet-base-cos-v1'
);
glob hastag_node:Hastag_node = Hastag_node();
glob tweet_main:Tweet_main = Tweet_main();
glob tweet_node:Tweet_node;
glob feed_obj:Feed_node;

walker Start {
    can start with `root entry {
        :g: tweet_node, feed_obj , tweet_main ;
        
        Jac.unrestrict(here, 1);
        feed_obj = Feed_node();
        [root, tweet_main] ++> (tweet_node := Tweet_node());
        Jac.unrestrict(tweet_node, 1);
        report tweet_node;
    }
}

walker follow_request {
    has followee_tweetnode_jid: str;

    can follow with `root entry {
        root +:Following():+> (&(self.followee_tweetnode_jid));
    }
}

walker tweet {
    has content: str;
    has tag: str;

    can tweet with `root entry {
        :g: tweet_node, hastag_node, feed_obj, model ;

        embedding = model.encode(self.content);
        embedding_str = base64.b64encode(embedding).decode('utf-8');
        tweet_node +:Tweeting():+> (user_tweet := Tweet(self.content, self.tag, embedding_str));
        hastag_node +:Hastag(self.tag):+> user_tweet;
        feed_obj.update_count(user_tweet.tag);
        report user_tweet;
    }
}

walker like {
    has tweet_jid: str;

    can like with `root entry {
        :g: feed_obj ;

        root +:Like():+> (tweet := &(self.tweet_jid));
        feed_obj.update_count(tweet.tag);
    }
}

walker comment {
    has tweet_jid: str;
    has content: str;

    can comment with `root entry {
        :g: feed_obj, model ;

        embedding = model.encode(self.content);
        embedding_str = base64.b64encode(embedding).decode('utf-8');
        (tweet := &(self.tweet_jid)) +:Reply():+> (user_comment := Comment(self.content, embedding_str));
        feed_obj.update_count(tweet.tag);
        report user_comment;
    }
}

walker load_feed {
    can feed with `root entry {
        :g: hastag_node, feed_obj ;

        for tweet in [root-:Following:->-:Tweeting:->] {
            report tweet;
        }
        for (key, value) in feed_obj.get_feed().items() {
            report [hastag_node-:Hastag:tag == key:->];
        }
    }
}

walker search {
    has query: str;

    can Search with entry {
        :g: hastag_node ;

        if (i := [hastag_node-:Hastag:tag == self.query:->]) {
            report i[0];
        } else {
            tweets = [tweet_main-->-->];
            docs = [tweet.content for tweet in [tweet_main-->-->]];
            scores = util.dot_score(
                model.encode(self.query),
                model.encode(docs)
            )[0].cpu().tolist();
            doc_score_pairs = list(zip([i for (i, _) in enumerate(docs)], scores));
            doc_score_pairs = sorted(
                doc_score_pairs,
                key=(with x: int can x[1]), reverse=True
            );
            Tweets = [tweets[i] for (i, _) in doc_score_pairs[:5]];
            report Tweets;
        }
    }
}
