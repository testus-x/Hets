-- |
-- simple key value assocciation list
-- implemented as unordered list of pairs
--
-- Version : $Id$

module Data.AssocList
    ( module Data.AssocList
    )
where

import Data.Maybe

type AssocList k v = [(k, v)]

-- lookup 	= lookup from Prelude

lookupDef	:: Eq k => v -> k -> AssocList k v -> v
lookupDef d k	= fromMaybe d . lookup k

lookup1		:: Eq k => k -> AssocList k [e] -> [e]
lookup1 k	= fromMaybe [] . lookup k

hasEntry	:: Eq k => k -> AssocList k v -> Bool
hasEntry k	= isJust . lookup k

-- addEntry is strict
addEntry	:: Eq k => k -> v -> AssocList k v -> AssocList k v
addEntry k v l	= ( (k,v) : ) $! delEntry k l

 -- let l' = delEntry k l in seq l' ((k, v) : l')

addEntries	:: Eq k => AssocList k v -> AssocList k v -> AssocList k v
addEntries	= foldr (.) id . map (uncurry addEntry) . reverse

-- delEntry is strict
delEntry	:: Eq k => k -> AssocList k v -> AssocList k v
delEntry _ []	= []
delEntry k (x@(k1,_) : rest)
    | k == k1	= rest
    | otherwise	= ( x : ) $! delEntry k rest

-- delEntry k	= filter ((/= k) . fst)

delEntries	:: Eq k => [k] -> AssocList k v -> AssocList k v
delEntries	= foldl (.) id . map delEntry

-- -----------------------------------------------------------------------------


