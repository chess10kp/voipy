import:py from sentence_transformers { SentenceTransformer, util }
node Hastag_node {}

node Hastag {
    has tag: str;
}

node Feed_node {
    has counts: dict = {};
    has total_count: int = 0;

    @classmethod
    can update_count(tag: str) {
        self.counts[tag] = self.counts.get(tag, 0) + 1;
        self.total_count += 1;
    }

    @classmethod
    can get_feed(feed_count: int=5) {
        if self.total_count == feed_count {
            return self.counts;
        }
        scale_factor = feed_count / self.total_count;
        feed = {key: round(value * scale_factor)  for (key, value) in counts.items()};
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
}

node Comment {
    has content: str;
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

walker Start {
    can start with `root entry {
        :g: tweet_node ;


        Jac.unrestrict(here, 1);
        feed_node = Feed_node();
        tweet_node = Tweet_node();
        root ++> [feed_node, tweet_node];
        tweet_main ++> tweet_node;
        Jac.unrestrict(tweet_node, 1);
        report feed_node;
        report tweet_node;
    }
}

walker follow_request {
    has followee_tnode_jid: str;

    can follow with `root entry {
        root +:Following():+> (&(self.followee_tnode_jid));
    }
}

walker tweet {
    has content: str;
    has tag: str;

    can tweet with `root entry {
        :g: tweet_node, hastag_node ;


        tweet_node +:Tweeting():+> (user_tweet := Tweet(self.content, self.tag));
        if (i := [hastag_node-->](?tag == self.tag)) {
            i[0] ++> user_tweet;
        } else {
            hastag_node ++> (hastag := Hastag(self.tag));
            hastag ++> user_tweet;
        }
        Jac.unrestrict(user_tweet, 1);
        Feed_node.update_count(user_tweet.tag);
        report user_tweet;
    }
}

walker like {
    has tweet_jid: str;

    can like with `root entry {
        root +:Like():+> (tweet := &(self.tweet_jid));
        Feed_node.update_count(tweet.tag);
    }
}

walker comment {
    has tweet_jid: str;
    has content: str;

    can comment with `root entry {
        (tweet := &(self.tweet_jid)) +:Reply():+> (user_comment := Comment(self.content));
        Feed_node.update_count(tweet.tag);
        report user_comment;
    }
}

walker load_feed {
    can feed with `root entry {
        :g: hastag_node ;

        for tweet in [root-:Following:->-:Tweeting:->] {
            report tweet;
        }
        for (key, value) in Feed_node.get_feed() {
            report ([hastag_node-->](?tag == self.key))[:value];
        }
    }
}

walker search {
    has query: str;

    can Search with entry {
        :g: hastag_node ;


        if (i := [hastag_node-->](?tag == self.query)) {
            report [i[0]-->];
        } else {
            for user in [tweet_main-->] {
                tweets = [tweet for tweet in [user-->]];
                docs = [tweet.content for tweet in [user-->]];
            }
            query_emb = model.encode(self.query);
            doc_emb = model.encode(docs);
            scores = util.dot_score(query_emb, doc_emb)[0].cpu().tolist();
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
