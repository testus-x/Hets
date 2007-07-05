{- |
Module      :  $Header$
Copyright   :  (c) Christian Maeder, Uni Bremen 2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  portable

'ShATermConvertible' instances for TiDecorate data types
-}

module Haskell.TiDecorateATC() where

import Common.ATerm.Lib
import TiDecorate
import Haskell.ATC_Haskell()
import Haskell.TiATC()
import Data.Typeable

{-! for TiDecls derive : Typeable !-}
{-! for TiDecl derive : Typeable !-}
{-! for TiExp derive : Typeable !-}
{-! for TiPat derive : Typeable !-}

{-! for TiDecls derive : ShATermConvertible !-}
{-! for TiDecl derive : ShATermConvertible !-}
{-! for TiExp derive : ShATermConvertible !-}
{-! for TiPat derive : ShATermConvertible !-}
