{- |
Module      :  $Header$
Description :  Signature for common logic
Copyright   :  (c) Karl Luc, DFKI Bremen 2010
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  kluc@informatik.uni-bremen.de
Stability   :  experimental
Portability :  portable

Definition of signatures for common logic
-}

module CommonLogic.Sign
    (Sign (..)
    , pretty                        -- pretty printing
    , allItems                      -- union of all signature-fields
    , emptySig                      -- empty signature
    , isSubSigOf                    -- sub signature of signature
    , sigDiff                       -- Difference of Signatures
    , unite                         -- union of signatures
    , uniteL                        -- union of a list ofsignatures
    , sigUnion                      -- Union for Logic.Logic
    , sigUnionL                     -- union of a list ofsignatures
    , isSeqMark                     -- is an Id a sequence marker?
    ) where

import qualified Data.Set as Set
import Common.Id
import Common.Result
import Common.Doc
import Common.DocUtils

-- | Datatype for common logic Signatures

data Sign = Sign { discourseNames :: Set.Set Id
                 , nondiscourseNames :: Set.Set Id
                 , sequenceMarkers :: Set.Set Id
                 } deriving (Eq, Ord, Show)

instance Pretty Sign where
    pretty = printSign

-- | union of all signature-fields
allItems :: Sign -> Set.Set Id
allItems s = Set.unions $ map (\f -> f s) [ discourseNames
                                          , nondiscourseNames
                                          , sequenceMarkers
                                          ]

-- | The empty signature
emptySig :: Sign
emptySig = Sign { discourseNames = Set.empty
                , nondiscourseNames = Set.empty
                , sequenceMarkers = Set.empty
                }

-- | pretty printing for Signatures
printSign :: Sign -> Doc
printSign s =
  vsep [ text "%{"
       , (text "discourseNames: ")
          <+> (sepByCommas $ map pretty $ Set.toList $ discourseNames s)
       , (text "nondiscourseNames: ")
          <+> (sepByCommas $ map pretty $ Set.toList $ nondiscourseNames s)
       , (text "sequenceMarkers: ")
          <+> (sepByCommas $ map pretty $ Set.toList $ sequenceMarkers s)
       , text "}%"]

-- | Determines if sig1 is subsignature of sig2
isSubSigOf :: Sign -> Sign -> Bool
isSubSigOf sig1 sig2 =
  Set.isSubsetOf (discourseNames sig1) (discourseNames sig2)
  && Set.isSubsetOf (nondiscourseNames sig1) (nondiscourseNames sig2)
  && Set.isSubsetOf (sequenceMarkers sig1) (sequenceMarkers sig2)

-- | difference of Signatures
sigDiff :: Sign -> Sign -> Sign
sigDiff sig1 sig2 = Sign {
  discourseNames = Set.difference (discourseNames sig1) (discourseNames sig2),
  nondiscourseNames = Set.difference (nondiscourseNames sig1) (nondiscourseNames sig2),
  sequenceMarkers = Set.difference (sequenceMarkers sig1) (sequenceMarkers sig2)
}

-- | Unite Signatures
sigUnion :: Sign -> Sign -> Result Sign
sigUnion s1 = Result [Diag Debug "All fine sigUnion" nullRange]
      . Just . unite s1

-- | Unite Signature in a list
sigUnionL :: [Sign] -> Result Sign
sigUnionL (sig : sigL) = sigUnion sig (uniteL sigL)
sigUnionL [] = return emptySig

unite :: Sign -> Sign -> Sign
unite sig1 sig2 = Sign {
  discourseNames = Set.union (discourseNames sig1) (discourseNames sig2),
  nondiscourseNames = Set.union (nondiscourseNames sig1) (nondiscourseNames sig2),
  sequenceMarkers = Set.union (sequenceMarkers sig1) (sequenceMarkers sig2)
}

uniteL :: [Sign] -> Sign
uniteL = foldr unite emptySig

isSeqMark :: Id -> Bool
isSeqMark = isStringSeqMark . tokStr . idToSimpleId

isStringSeqMark :: String -> Bool
isStringSeqMark s = take 3 s == "..."
