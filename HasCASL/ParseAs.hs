
{- HetCATS/HasCASL/ParseAs.hs
   $Id$
   Authors: Christian Maeder
   Year:    2002
   
   parser for HasCASL As
-}

module ParseAs where

import Id
import Keywords
import Lexer
import HToken
import As
import Parsec

colonT = asKey colonS
lessT = asKey lessS
equalT = asKey equalS
asT = asKey asP
plusT = asKey plusS
minusT = asKey minusS
dotT = try(asKey dotS <|> asKey cDot) <?> "dot"
crossT = try(asKey prodS <|> asKey timesS) <?> "cross"
barT = asKey barS
quMarkT = asKey quMark

qColonT = asKey (colonS++quMark)

forallT = asKey forallS

-----------------------------------------------------------------------------
-- classDecl
-----------------------------------------------------------------------------

pparseDownSet = 
	     do c <- className
		e <- equalT     
	        o <- oBraceT
		i <- typeVar
		d <- dotT
                j <- asKey (tokStr i)
		l <- lessT
                t <- parseType
		p <- cBraceT
		return (DownsetDefn c i t (map tokPos [e,o,d,j,l,p])) 

-----------------------------------------------------------------------------
-- kind
-----------------------------------------------------------------------------

parseClass = do t <- asKey typeS
		return (Universe (tokPos t))
             <|>
	     fmap ClassName className
             <|> 
	     do o <- oParenT
		(cs, ps) <- parseClass `separatedBy` commaT
		c <- cParenT
		return (Intersection cs (map tokPos (o:ps++[c])))

extClass = do c <- parseClass
	      do s <- plusT
	         return (ExtClass c CoVar (tokPos s))
	       <|> 
	       do s <- minusT
	          return (ExtClass c ContraVar (tokPos s))
	       <|> return (ExtClass c InVar nullPos)

isClass (ExtClass _ InVar _) = True
isClass _ = False
classOf (ExtClass c _ _) = c

prodClass = do (cs, ps) <- extClass `separatedBy` crossT
	       return (ProdClass cs (map tokPos ps))

kind = kindOrClass [] []

kindOrClass os ps = do c@(ProdClass cs _) <- prodClass
		       if length cs == 1 && isClass (head cs)
		         then curriedKind (os++[c]) ps 
				<|> return (Kind os (classOf (head cs)) 
				     (map tokPos ps))
		         else curriedKind (os++[c]) ps

curriedKind os ps = do a <- asKey funS
		       kindOrClass os (ps++[a])

-----------------------------------------------------------------------------
-- type
-----------------------------------------------------------------------------
-- a parsed type may also be interpreted as a kind (by the mixfix analysis)

idToken = pToken (scanQuotedChar <|> scanDotWords 
		 <|> scanDigit <|> scanWords <|> placeS <|> 
		  reserved hascasl_reserved_ops scanAnySigns)

typeToken :: GenParser Char st Type
typeToken = fmap TypeToken (pToken (toKey typeS <|> scanWords <|> placeS <|> 
				    reserved (hascasl_type_ops ++
					      hascasl_reserved_ops)
				    scanAnySigns))

braces p c = bracketParser p oBraceT cBraceT commaT c

primTypeOrId = fmap TypeToken idToken 
	       <|> braces typeOrId (BracketType Braces)
	       <|> brackets typeOrId (BracketType Squares)
	       <|> bracketParser typeOrId oParenT cParenT commaT
		       (BracketType Parens)
	       
typeOrId = do ts <- many1 primTypeOrId
	      let t = if length ts == 1 then head ts
 		      else MixfixType ts
		 in 
		 kindAnno t
 		 <|> 
		 return(t)

kindAnno t = do c <- colonT 
		k <- kind
		return (KindedType t k (tokPos c))

primType = typeToken 
	   <|> bracketParser parseType oParenT cParenT commaT 
		   (BracketType Parens)
	   <|> braces parseType (BracketType Braces)
           <|> brackets typeOrId (BracketType Squares)

lazyType = do q <- quMarkT
	      t <- primType 
              return (LazyType t (tokPos q))
	   <|> primType

mixType = do ts <- many1 lazyType
             let t = if length ts == 1 then head ts else MixfixType ts
	       in kindAnno t
		  <|> return t 

prodType = do (ts, ps) <- mixType `separatedBy` crossT
	      return (if length ts == 1 then head ts 
		      else ProductType ts (map tokPos ps)) 

funType = do (ts, as) <- prodType `separatedBy` arrowT
	     return (makeFun ts as)
	       where makeFun [t] [] = t
	             makeFun [t,r] [a] = FunType t (fst a) r (snd a)
		     makeFun (t:r) (a:b) = makeFun [t, makeFun r b] [a] 

arrowT = do a <- try(asKey funS) 
	    return (FunArr, tokPos a)
	 <|>
	 do a <- try(asKey pFun) 
	    return (PFunArr, tokPos a)
	 <|>
	 do a <- try(asKey contFun) 
	    return (ContFunArr, tokPos a)
         <|>
	 do a <- try(asKey pContFun) 
	    return (PContFunArr, tokPos a)

parseType :: GenParser Char st Type
parseType = funType  

-----------------------------------------------------------------------------
-- var decls, typevar decls, genVarDecls
-----------------------------------------------------------------------------

varDecls :: GenParser Char st [VarDecl]
varDecls = do (vs, ps) <- var `separatedBy` commaT
	      c <- colonT
	      t <- parseType
	      return (makeVarDecls vs ps t (tokPos c))

makeVarDecls vs ps t q = zipWith (\ v p -> VarDecl v t Comma (tokPos p))
		     (init vs) ps ++ [VarDecl (last vs) t Other q]

typeVarDecls :: GenParser Char st [TypeVarDecl]
typeVarDecls = do (vs, ps) <- typeVar `separatedBy` commaT
		  do   c <- colonT
		       t <- parseClass
		       return (makeTypeVarDecls vs ps t (tokPos c))
		    <|>
		    do l <- lessT
		       t <- parseType
		       return (makeTypeVarDecls vs ps (Downset t) (tokPos l))
		    <|> return (makeTypeVarDecls vs ps 
				(Universe nullPos) nullPos)

makeTypeVarDecls vs ps cl q = zipWith (\ v p -> 
				      TypeVarDecl v cl Comma (tokPos p))
					 (init vs) ps 
			      ++ [TypeVarDecl (last vs) cl Other q]

isSimpleId (Id ts _ _) = null (tail ts) && head (tokStr (head ts)) 
			 `elem` caslLetters

idToToken (Id ts _ _) = head ts

genVarDecls = do (vs, ps) <- var `separatedBy` commaT
		 if all isSimpleId vs then 
		    do   c <- colonT
			 t <- parseType
			 return (map GenVarDecl 
				 (makeVarDecls vs ps t (tokPos c)))
		       <|>
		       do l <- lessT
			  t <- parseType
			  return (map GenTypeVarDecl 
				  (makeTypeVarDecls 
				   (map idToToken vs) ps 
				   (Downset t) (tokPos l)))
		       <|> return(map GenTypeVarDecl 
				  (makeTypeVarDecls 
				   (map idToToken vs) ps 
				   (Universe nullPos) nullPos)) 
		    else
		    do   c <- colonT
			 t <- parseType
			 return (map GenVarDecl 
				 (makeVarDecls vs ps t (tokPos c)))
				 
-----------------------------------------------------------------------------
-- typeArgs
-----------------------------------------------------------------------------

extTypeVar :: GenParser Char st (TypeVar, Variance, Pos) 
extTypeVar = do t <- typeVar
		do   a <- plusT
		     return (t, CoVar, tokPos a)
	 	  <|>
		  do a <- plusT
		     return (t, ContraVar, tokPos a)
		  <|> return (t, InVar, nullPos)

isInVar(_, InVar, _) = True
isInVar(_,_,_) = False		    

typeArgs :: GenParser Char st [TypeArg]
typeArgs = do (ts, ps) <- extTypeVar `separatedBy` commaT
	      do   c <- colonT
                   if all isInVar ts then 
		      do k <- extClass
			 return (makeTypeArgs ts ps (tokPos c) k)
		      else do k <- parseClass
			      return (makeTypeArgs ts ps (tokPos c) 
				      (ExtClass k InVar nullPos))
	        <|> 
	        do l <- lessT
		   t <- parseType
		   return (makeTypeArgs ts ps (tokPos l)
			   (ExtClass (Downset t) InVar nullPos))
		<|> return (makeTypeArgs ts ps nullPos 
			   (ExtClass (Universe nullPos) InVar nullPos))
		where mergeVariance k e (t, InVar, _) p = 
			  TypeArg t e k p 
		      mergeVariance k (ExtClass c _ _) (t, v, ps) p =
			  TypeArg t (ExtClass c v ps) k p
		      makeTypeArgs ts ps q e = 
                         zipWith (mergeVariance Comma e) (init ts) 
				     (map tokPos ps)
			     ++ [mergeVariance Other e (last ts) q]


-----------------------------------------------------------------------------
-- type pattern
-----------------------------------------------------------------------------

typePatternToken :: GenParser Char st TypePattern
typePatternToken = fmap TypePatternToken (pToken (scanWords <|> placeS <|> 
				    reserved (hascasl_type_ops ++
					      formula_ops ++ 
					      hascasl_reserved_ops)
				    scanAnySigns))

primTypePatternOrId = fmap TypePatternToken idToken 
	       <|> braces typePatternOrId (BracketTypePattern Braces)
	       <|> brackets typePatternOrId (BracketTypePattern Squares)
	       <|> bracketParser typePatternArgs oParenT cParenT semiT
		       (BracketTypePattern Parens)

typePatternOrId = do ts <- many1 primTypePatternOrId
		     return( if length ts == 1 then head ts
 			     else MixfixTypePattern ts)

typePatternArgs = fmap TypePatternArgs typeArgs

primTypePattern = typePatternToken 
	   <|> bracketParser typePatternArgs oParenT cParenT semiT 
		   (BracketTypePattern Parens)
	   <|> braces typePattern (BracketTypePattern Braces)
           <|> brackets typePatternOrId (BracketTypePattern Squares)

typePattern = do ts <- many1 primTypePattern
                 let t = if length ts == 1 then head ts 
			 else MixfixTypePattern ts
	           in return t

-----------------------------------------------------------------------------
-- pattern
-----------------------------------------------------------------------------
-- a parsed pattern may also be interpreted as a type (by the mixfix analysis)
-- thus [ ... ] may be a mixfix-pattern, a compound list, 
-- or an instantiation with types

tokenPattern = fmap PatternToken idToken
					  
primPattern = tokenPattern 
	      <|> braces pattern (BracketPattern Braces) 
	      <|> brackets pattern (BracketPattern Squares)
	      <|> bracketParser patterns oParenT cParenT semiT 
		      (BracketPattern Parens)

patterns = do { (ts, ps) <- pattern `separatedBy` commaT
	      ; let tp = if length ts == 1 then head ts else 
		            TuplePattern ts (map tokPos ps)
		in return tp
	      }

mixPattern = do l <- many1 primPattern
                let p = if length l == 1 then head l else MixfixPattern l
		  in typedPattern p
		     <|> return p

typedPattern p = do { c <- colonT
		    ; t <- parseType
		    ; return (TypedPattern p t [tokPos c])
		    }

asPattern = do { v <- mixPattern
	       ; c <- asT 
	       ; t <- mixPattern 
	       ; return (AsPattern v t [tokPos c])
	       }

pattern = asPattern

-----------------------------------------------------------------------------
-- instOpName
-----------------------------------------------------------------------------
-- places may follow instantiation lists
instOpName = do i@(Id is cs ps) <- uninstOpName
		if isPlace (last is) then return (InstOpName i []) 
		   else do l <- many (brackets parseType Types)
			   u <- many placeT
			   return (InstOpName (Id (is++u) cs ps) l)

-----------------------------------------------------------------------------
-- typeScheme
-----------------------------------------------------------------------------

typeScheme = do f <- forallT
		(ts, cs) <- typeVarDecls `separatedBy` semiT
		d <- dotT
		t <- typeScheme
		return (TypeScheme (concat ts) t (map tokPos (f:cs++[d])))
	     <|> fmap SimpleTypeScheme parseType

-----------------------------------------------------------------------------
-- term
-----------------------------------------------------------------------------

tToken = pToken(scanFloat <|> scanString 
		       <|> scanQuotedChar <|> scanDotWords <|> scanWords 
		       <|> reserved hascasl_reserved_ops scanAnySigns 
		       <|> placeS <?> "id/literal" )

termToken = fmap TermToken (try (asKey exEqual) <|> tToken)

primTerm = termToken
	   <|> braces term (BracketTerm Braces)
	   <|> brackets term
		   (BracketTerm Squares)
 	   <|> parenTerm
           <|> forallTerm
	   <|> exTerm
	   <|> lambdaTerm
	   <|> caseTerm


parenTerm = do o <- oParenT
	       varTerm o
	         <|>
		 qualOpName o
		 <|> 
		 qualPredName o
		 <|>
		 do (ts, ps) <- option ([],[]) (term `separatedBy` commaT)
		    p <- cParenT
		    return (BracketTerm Parens ts (map tokPos (o:ps++[p])))
		     		
partialTypeScheme :: GenParser Char st (Token, TypeScheme)
partialTypeScheme = do q <- try (qColonT)
		       t <- parseType 
		       return (q, SimpleTypeScheme (LazyType t (tokPos q)))
		    <|> bind (,) colonT typeScheme

varTerm o = do v <- asKey varS
	       i <- var
	       c <- colonT
	       t <- parseType
	       p <- cParenT
	       return (QualVar i t (map tokPos [o,v,c,p]))

qualOpName o = do { v <- asKey opS
		  ; i <- instOpName
 	          ; (c, t) <- partialTypeScheme
		  ; p <- cParenT
		  ; return (QualOp i t (map tokPos [o,v,c,p]))
		  }

predType t = FunType t PFunArr (ProductType [] []) nullPos
predTypeScheme (SimpleTypeScheme t) = SimpleTypeScheme (predType t)
predTypeScheme (TypeScheme vs t ps) = TypeScheme vs (predTypeScheme t) ps

qualPredName o = do { v <- asKey predS
		    ; i <- instOpName
		    ; c <- colonT 
		    ; t <- typeScheme
		    ; p <- cParenT
		    ; return (QualOp i (predTypeScheme t) 
			      (map tokPos [o,v,c,p]))
		  }



typeQual = try $
	      do q <- colonT
	         return (OfType, q)
	      <|> 
	      do q <- asKey (asS)
	         return (AsType, q)
	      <|> 
	      do q <- asKey (inS)
	         return (InType, q)


typedTerm f = do (q, p) <- typeQual
		 t <- parseType
		 return (TypedTerm f q t (tokPos p))

mixTerm = do ts <- many1 primTerm
	     let t = if length ts == 1 then head ts else MixfixTerm ts
		 in typedTerm t <|> return t

term = do t <- mixTerm  
	  whereTerm t <|> return t

-----------------------------------------------------------------------------
-- quantified term
-----------------------------------------------------------------------------

forallTerm = do f <- try forallT
		(vs, ps) <- genVarDecls `separatedBy` semiT
		d <- dotT
		t <- term
		return (QuantifiedTerm Universal (concat vs) t 
			(map tokPos (f:ps++[d])))

exQuant = try(
        do { q <- asKey (existsS++exMark)
	   ; return (Unique, q)
	   }
        <|>
        do { q <- asKey existsS
	   ; return (Existential, q)
	   })

exTerm = do { (q, p) <- exQuant
	    ; (vs, ps) <- varDecls `separatedBy` semiT
	    ; d <- dotT
	    ; f <- term
	    ; return (QuantifiedTerm q (map GenVarDecl (concat vs)) f
		      (map tokPos (p:ps++[d])))
	    }


lamDot = do d <- asKey (dotS++exMark) <|> asKey (cDot++exMark)
	    return (Total,d)
	 <|> 
	 do d <- dotT
	    return (Partial,d)

lambdaTerm = do l <- try (asKey lamS)
		pl <- lamPattern
		(k, d) <- lamDot      
		t <- term
		return (LambdaTerm pl k t (map tokPos [l,d]))

lamPattern = do (vs, ps) <- varDecls `separatedBy` semiT
		return [PatternVars (concat vs) (map tokPos ps)]
	     <|> 
	     many (bracketParser patterns oParenT cParenT semiT 
		      (BracketPattern Parens)) 

-----------------------------------------------------------------------------
-- case-term, where-term
-----------------------------------------------------------------------------

caseTerm = do c <- try(asKey caseS)
	      t <- term
	      o <- asKey ofS
	      (ts, ps) <- patternTermPair funS `separatedBy` barT
	      return (CaseTerm t ts (map tokPos (c:o:ps)))

patternTermPair :: String -> GenParser Char st ProgEq
patternTermPair sep = do p <- pattern
			 s <- asKey sep
			 t <- term
			 return (ProgEq p t (tokPos s))

whereTerm t = do w <- try $ asKey whereS
		 (ts, ps) <- patternTermPair equalS `separatedBy` commaT
		 return (WhereTerm t ts (map tokPos (w:ps)))
           