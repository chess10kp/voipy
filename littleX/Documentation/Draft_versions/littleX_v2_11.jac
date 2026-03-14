import:py from sentence_transformers { SentenceTransformer, util }
import:py from cryptography.fernet { Fernet }
import:py base64;
node Hastag_node {}

node Hastag {
    has tag: str;
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
    has encrypted: str;
}

node Comment {
    has content: str;
    has encrypted: str;
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
glob key: bytes;
glob cipher_suite:Fernet;

walker Start {
    can start with `root entry {
        :g: tweet_main, tweet_node, feed_obj, key, cipher_suite ;

        key = Fernet.generate_key();
        cipher_suite = Fernet(key);
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
        :g: tweet_node, hastag_node, feed_obj ;

        encrypted_bytes = cipher_suite.encrypt(self.content.encode());
        encrypted = base64.urlsafe_b64encode(encrypted_bytes).decode();
        tweet_node +:Tweeting():+> (user_tweet := Tweet(self.content, self.tag, encrypted));
        if (i := [hastag_node-->](?tag == self.tag)) {
            i[0] ++> user_tweet;
        } else {
            hastag_node ++> (hastag := Hastag(self.tag));
            hastag ++> user_tweet;
        }
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
        :g: cipher_suite, feed_obj ;

        encrypted_bytes = cipher_suite.encrypt(self.content.encode());
        encrypted = base64.urlsafe_b64encode(encrypted_bytes).decode();
        (tweet := &(self.tweet_jid)) +:Reply():+> (user_comment := Comment(self.content, encrypted));
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
            report [[hastag-->] for hastag in ([hastag_node-->](?tag == key))];
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
