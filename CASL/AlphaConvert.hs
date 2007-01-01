{- |
Module      :  $Header$
Description :  alpha-conversion (renaming of bound variables) for CASL formulas
Copyright   :  (c) Christian Maeder, Uni Bremen 2005
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  maeder@tzi.de
Stability   :  provisional
Portability :  portable

uniquely rename variables in quantified formulas to allow for 
a formula equality modulo alpha conversion
-}

module CASL.AlphaConvert (alphaEquiv, convertFormula) where

import CASL.AS_Basic_CASL
import CASL.Fold
import CASL.Utils
import CASL.Quantification
import qualified Common.Lib.Map as Map
import Common.Id

convertRecord :: Int -> (f -> f) -> Record f (FORMULA f) (TERM f)
convertRecord n mf = (mapRecord mf)
    { foldQuantification = \ (Quantification q vs qf ps) _ _ _ _ -> 
      let nvs = flatVAR_DECLs vs
          mkVar i = mkSimpleId $ "v" ++ show i
          rvs = map mkVar [n .. ]
          nf = replace_varsF (Map.fromList $ zipWith ( \ (v, s) i -> 
                             (v, Qual_var i s ps)) nvs rvs) mf 
               $ convertFormula (n + length nvs) mf qf
      in foldr ( \ (v, s) cf -> 
           Quantification q [Var_decl [v] s ps] cf ps)
             nf $ zip rvs $ map snd nvs    
    }

{- | uniquely rename variables in quantified formulas and always
     quantify only over a single variable -}
convertFormula :: Int -> (f -> f) -> FORMULA f -> FORMULA f
convertFormula n = foldFormula . convertRecord n

-- | formula equality modulo alpha conversion
alphaEquiv :: Eq f => (f -> f) -> FORMULA f -> FORMULA f -> Bool
alphaEquiv mf f1 f2 = 
    convertFormula 1 mf f1 == convertFormula 1 mf f2
