
{- HetCATS/HasCASL/PrintLe.hs
   $Id$
   Authors: Christian Maeder
   Year:    2002
   
   printing Le data types
-}

module HasCASL.PrintLe where

import HasCASL.As
import HasCASL.HToken
import HasCASL.PrintAs
import HasCASL.Le
import Data.Maybe
import Common.PrettyPrint
import Common.Lib.Pretty
import qualified Common.Lib.Map as Map
import Common.Keywords
import Common.GlobalAnnotations

printList0 :: (PrettyPrint a) => GlobalAnnos -> [a] -> Doc
printList0 ga l = noPrint (null l)
		      (if null $ tail l then printText0 ga $ head l
		       else parens $ commas ga l)

instance PrettyPrint ClassInfo where
    printText0 ga (ClassInfo sups defn) =
	noPrint (isNothing defn)
	   (ptext equalS <+> printText0 ga defn)
	<> noPrint (null sups || isNothing defn) space
	<> noPrint (null sups)
	   (ptext lessS <+> printList0 ga sups)

instance PrettyPrint TypeDefn where
    printText0 _ NoTypeDefn = empty
    printText0 _ TypeVarDefn = space <> ptext "%(var)%"
    printText0 ga (AliasTypeDefn s) = space <> ptext assignS 
				      <+> printPseudoType ga s
    printText0 ga (Supertype v t f) = space <> ptext equalS <+> 
					 braces (printText0 ga v 
					   <+> colon
					   <+> printText0 ga t 
					   <+> text dotS
					   <+> printText0 ga f)
    printText0 _ (DatatypeDefn k)  = ptext " %%" <>
	let om = ptext " type definition omitted"
					 in case k of
				     Loose -> om
				     Free -> space <> ptext freeS <> om
				     Generated -> space <> ptext generatedS 
						  <> om

instance PrettyPrint TypeInfo where
    printText0 ga (TypeInfo k ks sups defn) =
	colon <> printList0 ga (k:ks) 
	<> noPrint (null sups)
	   (ptext lessS <+> printList0 ga sups)
        <> printText0 ga defn

instance PrettyPrint [Kind] where
    printText0 ga l = colon <> printList0 ga l

instance PrettyPrint [Type] where
    printText0 ga l = colon <> printList0 ga l

instance PrettyPrint [TypeScheme] where
    printText0 ga l = colon <+> printList0 ga l

instance PrettyPrint [ClassId] where
    printText0 ga l = colon <+> printList0 ga l

instance PrettyPrint a => PrettyPrint (Maybe a) where
    printText0 _ Nothing = empty
    printText0 ga (Just c) =  printText0 ga c

instance (PrettyPrint a, Ord a, PrettyPrint b) 
    => PrettyPrint (Map.Map a b) where
    printText0 ga m =
	let l = Map.toList m in
	    vcat(map (\ (a, b) -> printText0 ga a <+> printText0 ga b) l)

instance PrettyPrint Env where
    printText0 ga e = printText0 ga (classMap e)
	$$ ptext "Type Constructors"
	$$ printText0 ga (typeMap e)
	$$ ptext "Assumptions"
        $$ printText0 ga (assumps e)  
	$$ vcat (map (printText ga) (reverse $ envDiags e))

