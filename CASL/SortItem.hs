
{- HetCATS/CASL/SortItem.hs
   $Id$
   Authors: Christian Maeder
   Year:    2002
   
   parse SORT-ITEM and "sort/sorts SORT-ITEM ; ... ; SORT-ITEM"

   http://www.cofi.info/Documents/CASL/Summary/
   from 25 March 2001

   C.2.1 Basic Specifications with Subsorts
-}

module SortItem where

import Id
import Keywords
import Lexer
import AS_Basic_CASL
import AS_Annotation
import Parsec
import Token
import Formula
import ItemList (annos, itemList)

-- ------------------------------------------------------------------------
-- sortItem
-- ------------------------------------------------------------------------

commaSortDecl :: Id -> GenParser Char st SORT_ITEM
commaSortDecl s = do c <- commaT 
		     (is, cs) <- sortId `separatedBy` commaT
		     let l = s : is 
		         p = tokPos c : map tokPos cs in
		       subSortDecl (l, p) <|> return (Sort_decl l p)

isoDecl :: Id -> GenParser Char st SORT_ITEM
isoDecl s = do e <- equalT
               subSortDefn (s, tokPos e)
		 <|>
		 (do (l, p) <- sortId `separatedBy` equalT
		     return (Iso_decl (s:l) (tokPos e : map tokPos p)))

subSortDefn :: (Id, Pos) -> GenParser Char st SORT_ITEM
subSortDefn (s, e) = do a <- annos
			o <- oBraceT
			v <- varId
			c <- colonT
			t <- sortId
			d <- dotT -- or bar
			f <- formula
			p <- cBraceT
			return (Subsort_defn s v t (Annoted f [] a []) 
				(e:tokPos o:tokPos c:tokPos d:[tokPos p]))

subSortDecl :: ([Id], [Pos]) -> GenParser Char st SORT_ITEM
subSortDecl (l, p) = do t <- lessT
			s <- sortId
			return (Subsort_decl l s (p++[tokPos t]))

sortItem :: GenParser Char st SORT_ITEM 
sortItem = do s <- sortId ;
	      subSortDecl ([s],[])
		    <|>
		    commaSortDecl s
		    <|>
                    isoDecl s
		    <|> 
		    return (Sort_decl [s] [])

sortItems :: GenParser Char st SIG_ITEMS
sortItems = itemList sortS sortItem Sort_items

