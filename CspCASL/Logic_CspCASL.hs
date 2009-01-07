{- |
Module      :  $Id$
Description :  CspCASL instance of type class logic
Copyright   :  (c)  Markus Roggenbach, Till Mossakowski and Uni Bremen 2003
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  M.Roggenbach@swansea.ac.uk
Stability   :  experimental
Portability :  non-portable(import Logic.Logic)

Here is the place where the class Logic is instantiated for CspCASL.
   Also the instances for Syntax an Category.
-}
{-
   todo:
     - writing real functions
     - Modul Sign.hs mit CSP-CASL-Signaturen und Morphismen, basiernd
       auf CASL.Sign
          CSP-CASL-Signatur = (CASL-Sig,Menge von Kanalnamen)
          CSP-CASL-Morphismus = (CASL-Morphismus, Kanalnamenabbildung)
                      oder nur CASL-Morphismus
          SYMB_ITEMS SYMB_MAP_ITEMS: erstmal von CASL (d.h. nur CASL-Morphismus)
     - instance Sentences
        S�tze = entweder CASL-S�tze oder CSP-CASL-S�tze
        Rest soweit wie m�glich von CASL �bernehmen
     - statische Analyse (gem�� Typ in Logic.Logic) schreiben
       und unten f�r basic_analysis einh�ngen

    K�r:
     - Teillogiken (instance SemiLatticeWithTop ...)

-}

module CspCASL.Logic_CspCASL(CspCASL(CspCASL)) where

import Logic.Logic

import CASL.AS_Basic_CASL
import CASL.Logic_CASL
import CASL.Morphism
import CASL.Sign
import CASL.SymbolParser
import CASL.SymbolMapAnalysis

import qualified Data.Set as Set

--import CspCASL.AS_CspCASL
import qualified CspCASL.AS_CspCASL as AS_CspCASL
import qualified CspCASL.ATC_CspCASL()
import qualified CspCASL.CspCASL_Keywords as CspCASL_Keywords
import qualified CspCASL.Morphism as CspCASL_Morphism
import qualified CspCASL.Parse_CspCASL as Parse_CspCASL
import qualified CspCASL.Print_CspCASL ()
import qualified CspCASL.SignCSP as SignCSP
import qualified CspCASL.SimplifySen as SimplifySen
import qualified CspCASL.StatAnaCSP as StatAnaCSP

-- | Lid for CspCASL
data CspCASL = CspCASL deriving (Show)

instance Language CspCASL
    where
      description _ =
        "CspCASL - see\n\n"++
        "http://www.cs.swan.ac.uk/~csmarkus/ProcessesAndData/"

instance SignExtension SignCSP.CspSign where
  isSubSignExtension = SignCSP.isInclusion

-- | Instance for CspCASL morphism extension (used for Category)
instance MorphismExtension SignCSP.CspSign SignCSP.CspAddMorphism where
  ideMorphismExtension _ = SignCSP.emptyCspAddMorphism
  composeMorphismExtension = SignCSP.composeCspAddMorphism
  inverseMorphismExtension = SignCSP.inverseCspAddMorphism
  isInclusionMorphismExtension _ = True -- missing!

-- | Instance of Sentences for CspCASL (missing)
instance Sentences CspCASL
    SignCSP.CspCASLSen   -- sentence (missing)
    SignCSP.CspCASLSign     -- signature
    SignCSP.CspMorphism     -- morphism
    Symbol               -- symbol
    where
      map_sen CspCASL mor sen =
        if isInclusionMorphism isInclusionMorphismExtension mor
        then return sen
        else fail "renaming in map_sen CspCASL not implemented"
      parse_sentence CspCASL = Nothing
      sym_of CspCASL = CspCASL_Morphism.symOf
      symmap_of CspCASL = morphismToSymbMap
      sym_name CspCASL = symName
      simplify_sen CspCASL = SimplifySen.simplifySen

-- | Syntax of CspCASL
instance Syntax CspCASL
    AS_CspCASL.CspBasicSpec -- basic_spec
    SYMB_ITEMS              -- symb_items
    SYMB_MAP_ITEMS          -- symb_map_items
    where
      parse_basic_spec CspCASL =
          Just Parse_CspCASL.cspBasicSpec
      parse_symb_items CspCASL =
          Just $ symbItems CspCASL_Keywords.csp_casl_keywords
      parse_symb_map_items CspCASL =
          Just $ symbMapItems CspCASL_Keywords.csp_casl_keywords

-- lattices (for sublogics) missing

-- | Instance of Logic for CspCASL
instance Logic CspCASL
    ()                      -- Sublogics (missing)
    AS_CspCASL.CspBasicSpec -- basic_spec
    SignCSP.CspCASLSen   -- sentence (missing)
    SYMB_ITEMS              -- symb_items
    SYMB_MAP_ITEMS          -- symb_map_items
    SignCSP.CspCASLSign         -- signature
    SignCSP.CspMorphism     -- morphism
    Symbol
    RawSymbol
    ()                      -- proof_tree (missing)
    where
      stability CspCASL = Experimental
      data_logic CspCASL = Just (Logic CASL)
      empty_proof_tree _ = ()

-- | Static Analysis for CspCASL
instance StaticAnalysis CspCASL
    AS_CspCASL.CspBasicSpec -- basic_spec
    SignCSP.CspCASLSen   -- sentence (missing)
    SYMB_ITEMS              -- symb_items
    SYMB_MAP_ITEMS          -- symb_map_items
    SignCSP.CspCASLSign         -- signature
    SignCSP.CspMorphism     -- morphism
    Symbol
    RawSymbol
    where
      basic_analysis CspCASL =
          Just StatAnaCSP.basicAnalysisCspCASL
      stat_symb_map_items CspCASL = error "Logic_CspCASL.hs"
      stat_symb_items CspCASL = error "Logic_CspCASL.hs"
      empty_signature CspCASL = SignCSP.emptyCspCASLSign
      inclusion CspCASL =
          sigInclusion SignCSP.emptyCspAddMorphism
          SignCSP.isInclusion const -- this is still wrong
      signature_union CspCASL s =
          return . addSig SignCSP.addCspProcSig s
      induced_from_morphism CspCASL = inducedFromMorphism
                                      SignCSP.emptyCspAddMorphism
                                      SignCSP.isInclusion
      induced_from_to_morphism CspCASL = inducedFromToMorphism
                                         SignCSP.emptyCspAddMorphism
                                         SignCSP.isInclusion
                                         SignCSP.diffCspProcSig
