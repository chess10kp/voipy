# import:py from fastapi { FastAPI, HTTPException }
import:py from sentence_transformers { SentenceTransformer, util }
import:py numpy as np;
node Hastag_node {}

node Hastag {
    has tag: str;
}

node Feed_node {}

node Tweet_main {}

node Tweet_node {}

node Tweet {
    has content: str;
    has tag: str;
    # has embedding:np.ndarray;
}

node Comment {
    has content: str;
    # has embedding:np.array;
}

edge Following {}

edge Tweeting {}

edge Reply {}

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
        report feed_node;
        report tweet_node;
    }
}

walker follow_request {
    has followee_tnode_jid: str;

    can follow with `root entry {
        root +:Following():+> (&(self.followee_tnode_jid));
        report [root-->];
    }
}

walker tweet {
    has content: str;
    has tag: str;

    can tweet with `root entry {
        :g: tweet_node ;
        # model = SentenceTransformer('sentence-transformers/multi-qa-mpnet-base-cos-v1');

        # embedding = model.encode(self.content);



        tweet_node +:Tweeting():+> (user_tweet := Tweet(self.content, self.tag));
        tags = [i.tag for i in [hastag_node-->]];
        if self.tag not in tags {
            hastag_node ++> Hastag(self.tag);
        }
        Jac.unrestrict(user_tweet, 1);
        report user_tweet;
        report [hastag_node-->];
    }
}

walker comment {
    has tweet_jid: str;
    has content: str;

    can comment with `root entry {
        &(self.tweet_jid) +:Reply():+> (user_comment := Comment(self.content));
        report user_comment;
    }
}

walker load_feed {
    can feed with `root entry {
        feed_list = [];
        followee_list = [root-:Following:->];
        
        for followee in followee_list {
            for tweet in [followee-->] {
                feed_list.append(jid(tweet));
            }
        }
        report [&i for i in feed_list];
    }
}

walker search {
    has query: str;

    can Search with entry {
        search_tag: any = None;
        :g: hastag_node ;

        
        for hastag in [hastag_node-->] {
            if hastag.tag == self.query {
                search_tag = hastag;
            }
        }
        search_result = [search_tag-->] if search_tag else [];
        if (not search_tag) {
            for tweet_node in [tweet_main-->] {
                search_result.append(self.deep_search([tweet_node-->]));
                search_result = sorted(
                    search_result,
                    key=(with x: int can x[1]), reverse=True
                );

                # search_result = search_result[:5];
            }
        }
        report search_result if search_result else None;
    }

    can deep_search(tweet_list: list) -> list {
        model = SentenceTransformer(
            'sentence-transformers/multi-qa-mpnet-base-cos-v1'
        );
        docs = [i.content for i in tweet_list];
        query_emb = model.encode(self.query);
        doc_emb = model.encode(docs);
        scores = util.dot_score(query_emb, doc_emb)[0].cpu().tolist();
        doc_score_pairs = list(zip(tweet_list, scores));
        doc_score_pairs = sorted(
            doc_score_pairs,
            key=(with x: int can x[1]), reverse=True
        );
        return doc_score_pairs;
    }
}
