{- |
Module      :  $Header$
Copyright   :  (c) Christian Maeder and Uni Bremen 2003 
Licence     :  similar to LGPL, see HetCATS/LICENCE.txt or LIZENZ.txt

Maintainer  :  hets@tzi.de
Stability   :  experimental
Portability :  portable 

   substitution and unification of types
-}

module HasCASL.Unify where

import HasCASL.As
import HasCASL.AsUtils
import Common.PrettyPrint
import Common.Id
import HasCASL.Le
import Common.Lib.State
import Common.Lib.Parsec
import qualified Common.Lib.Map as Map
import Common.Result
import Data.List
import Data.Maybe

varsOf :: Type -> [TypeArg]
varsOf t = 
    case t of 
	   TypeName j k i -> if i > 0 then [TypeArg j k Other []] else []
	   TypeAppl t1 t2 -> varsOf t1 ++ varsOf t2
	   TypeToken _ -> []
	   BracketType _ l _ -> concatMap varsOf l
	   KindedType tk _ _ -> varsOf tk
	   MixfixType l -> concatMap varsOf l
	   LazyType tl _ -> varsOf tl
	   ProductType l _ -> concatMap varsOf l
	   FunType t1 _ t2 _ -> varsOf t1 ++ varsOf t2


generalize :: TypeScheme -> TypeScheme
generalize (TypeScheme vs q@(_ :=> ty) ps) =
    TypeScheme (nub (varsOf ty)) q ps

-- | composition (reversed: first substitution first!)
compSubst :: Subst -> Subst -> Subst
compSubst s1 s2 = Map.union (Map.map (subst s2) s1) s2  

-- | unifiability of type schemes including instantiation with fresh variables 
-- (and looking up type aliases)
isUnifiable :: TypeMap -> Int -> TypeScheme -> TypeScheme -> Bool
isUnifiable tm c = asSchemes c (unify tm) 

-- | test if second scheme is a substitution instance
instScheme :: TypeMap -> Int -> TypeScheme -> TypeScheme -> Bool
instScheme tm c = asSchemes c (subsume tm) 

-- | lift 'State' Int to 'State' Env
toEnvState :: State Int a -> State Env a 
toEnvState p = 
    do s <- get
       let (r, c) = runState p $ counter s
       put s { counter = c }
       return r 

toSchemes :: (Type -> Type -> a) -> TypeScheme -> TypeScheme -> State Int a
toSchemes f sc1 sc2 =
    do t1 <- freshInst sc1
       t2 <- freshInst sc2
       return $ f t1 t2

asSchemes :: Int -> (Type -> Type -> a) -> TypeScheme -> TypeScheme -> a
asSchemes c f sc1 sc2 = fst $ runState (toSchemes f sc1 sc2) c

-- -------------------------------------------------------------------------
freshInst :: TypeScheme -> State Int Type
freshInst (TypeScheme tArgs (_ :=> t) _) = 
    do m <- mkSubst tArgs 
       return $ subst m t

freshVar :: State Int Id 
freshVar = 
    do c <- get
       put (c + 1)
       return $ simpleIdToId $ mkSimpleId ("_var_" ++ show c)

mkSingleSubst :: TypeArg -> State Int Subst
mkSingleSubst tv@(TypeArg _ k _ _) =
    do ty <- freshVar
       return $ Map.single tv $ TypeName ty k 1

mkSubst :: [TypeArg] -> State Int Subst
mkSubst tas = do ms <- mapM mkSingleSubst tas
		 return $ Map.unions ms
 		   
type Subst = Map.Map TypeArg Type

eps :: Subst
eps = Map.empty

instance Ord TypeArg where
    TypeArg v1 _ _ _ <= TypeArg v2 _ _ _
	= v1 <= v2

class Unifiable a where
    subst :: Subst -> a -> a
    match :: TypeMap -> (Bool, a) -> (Bool, a) -> Result Subst

-- | most general unifier via 'match' 
-- where both sides may contribute substitutions
mgu :: Unifiable a => TypeMap -> a -> a -> Result Subst
mgu tm a b = match tm (True, a) (True, b)

unify :: Unifiable a => TypeMap -> a -> a -> Bool
unify tm a b = isJust $ maybeResult $ mgu tm a b 

subsume :: Unifiable a => TypeMap -> a -> a -> Bool
subsume tm a b = isJust $ maybeResult $ match tm (False, a) (True, b)

equalSubs :: Unifiable a => TypeMap -> a -> a -> Bool
equalSubs tm a b = subsume tm a b && subsume tm b a

starTypeInfo :: TypeInfo
starTypeInfo = TypeInfo star [] [] NoTypeDefn

instance Unifiable Type where
    subst m t = case t of
	   TypeName i k _ -> 
	       case Map.lookup (TypeArg i k Other []) m of
	       Just s -> s
	       _ -> t
	   TypeAppl t1 t2 ->
	       TypeAppl (subst m t1) (subst m t2)
	   TypeToken _ -> t
	   BracketType b l ps ->
	       BracketType b (map (subst m) l) ps
	   KindedType tk k ps -> 
	       KindedType (subst m tk) k ps
	   MixfixType l -> MixfixType $ map (subst m) l
	   LazyType tl ps -> LazyType (subst m tl) ps
	   ProductType l ps -> ProductType (map (subst m) l) ps
           FunType t1 a t2 ps -> FunType (subst m t1) a (subst m t2) ps
			-- lookup type aliases
    match tm t1 (b2, LazyType t2 _) = match tm t1 (b2, t2)
    match tm (b1, LazyType t1 _) t2 = match tm (b1, t1) t2
    match tm t1 (b2, KindedType t2 _ _) = match tm t1 (b2, t2)
    match tm (b1, KindedType t1 _ _) t2 = match tm (b1, t1) t2
    match tm (b1, t1@(TypeName i1 k1 v1)) (b2, t2@(TypeName i2 k2 v2)) =
	if i1 == i2 ||
	   (any (occursIn tm i1) $ superTypes $ 
	       Map.findWithDefault starTypeInfo i2 tm)
           || (any (occursIn tm i2) $ superTypes $ 
	       Map.findWithDefault starTypeInfo i1 tm)
	   then return eps
	else if v1 > 0 && b1 then return $ 
	        Map.single (TypeArg i1 k1 Other []) t2
		else if v2 > 0 && b2 then return $
		     Map.single (TypeArg i2 k2 Other []) t1
			else let (a1, e1) = expandAlias tm t1 
				 (a2, e2) = expandAlias tm t2 in
			if e1 || e2 then match tm (b1, a1) (b2, a2)
			   else uniResult "typename" i1 
				    "is not unifiable with typename" i2
    match tm (b1, t1@(TypeName i1 k1 v1)) (b2, t2) =
	if v1 > 0 && b1 then 
	   if occursIn tm i1 t2 then 
	      uniResult "var" i1 "occurs in" t2
	   else return $
			Map.single (TypeArg i1 k1 Other []) t2
	else let (a1, e1) = expandAlias tm t1 in
		 if e1 then match tm (b1, a1) (b2, t2)
		   else uniResult "typename" i1  
			    "is not unifiable with type" t2
    match tm t2 t1@(_, TypeName _ _ _) = match tm t1 t2
    match tm (b1, t12@(TypeAppl t1 t2)) (b2, t34@(TypeAppl t3 t4)) = 
	let (ta, a) = expandAlias tm t12
	    (tb, b) = expandAlias tm t34 in
	   if a || b then match tm (b1, ta) (b2, tb)
	      else match tm (b1, (t1, t2)) (b2, (t3, t4))
    match tm (b1, ProductType p1 _) (b2, ProductType p2 _) = 
	match tm (b1, p1) (b2, p2)
    match tm (b1, FunType t1 _ t2 _) (b2, FunType t3 _ t4 _) = 
	match tm (b1, (t1, t2)) (b2, (t3, t4))
    match _ (_,t1) (_,t2) = uniResult "type" t1  
			    "is not unifiable with type" t2

showPrettyWithPos :: (PrettyPrint a, PosItem a) => a -> ShowS
showPrettyWithPos a = let p = getMyPos a 
			  s = ("'" ++) . showPretty a . ("'" ++)
			  n = sourceName p in 
    if nullPos == p then s else s . (" (" ++) .
       (if null n then id else (n ++) . (", " ++))
       . ("line " ++) . shows (sourceLine p)
       . (", column " ++) . shows (sourceColumn p)
       .  (")" ++) 

uniResult :: (PrettyPrint a, PosItem a, PrettyPrint b, PosItem b) =>
	      String -> a -> String -> b -> Result Subst
uniResult s1 a s2 b = 
      Result [Diag Hint ("in type\n" ++ "  " ++ s1 ++ " " ++
			 showPrettyWithPos a "\n  " ++ s2 ++ " " ++
			 showPrettyWithPos b "") nullPos] Nothing

instance (Unifiable a, Unifiable b) => Unifiable (a, b) where  
    subst s (t1, t2) = (subst s t1, subst s t2)
    match tm (b1, (t1, t2)) (b2, (t3, t4)) =
	let r1@(Result _ m1) = match tm (b1, t1) (b2, t3) in
	   case m1 of
	       Nothing -> r1
	       Just s1 -> let r2@(Result _ m2) =
				 match tm (b1, if b1 then subst s1 t2 else t2) 
					  (b2, if b2 then subst s1 t4 else t4)
			      in case m2 of 
				     Nothing -> r2
				     Just s2 -> return $ compSubst s1 s2

instance (PrettyPrint a, PosItem a, Unifiable a) => Unifiable [a] where
    subst s = map (subst s) 
    match _ (_, []) (_, []) = return eps
    match tm (b1, a1:r1) (b2, a2:r2) = match tm (b1, (a1, r1)) (b2, (a2, r2))
    match tm (b1, []) l = match tm l (b1, [])
    match _ (_, (a:_)) (_, []) = uniResult "type component" a 
		       "is not unifiable with the empty list" 
		       (mkSimpleId "[]")


instance (PrettyPrint a, PosItem a, Unifiable a) => Unifiable (Maybe a) where
    subst s = fmap (subst s) 
    match _ (_, Nothing) _ = return eps
    match _ _ (_, Nothing) = return eps
    match tm (b1, Just a1) (b2, Just a2) = match tm (b1, a1) (b2, a2)

occursIn :: TypeMap -> TypeId -> Type -> Bool
occursIn tm i t = 
    case t of 
	   TypeName j _ _ -> i == j || (any (occursIn tm i) $ superTypes $ 
	       Map.findWithDefault starTypeInfo j tm)
	   TypeAppl t1 t2 -> occursIn tm i t1 || occursIn tm i t2
	   TypeToken tk -> i == simpleIdToId tk 
	   BracketType _ l _ -> any (occursIn tm i) l
	   KindedType tk _ _ -> occursIn tm i tk
	   MixfixType l -> any (occursIn tm i) l
	   LazyType tl _ -> occursIn tm i tl
	   ProductType l _ -> any (occursIn tm i) l
	   FunType t1 _ t2 _ -> occursIn tm i t1 || occursIn tm i t2

expandAlias :: TypeMap -> Type -> (Type, Bool)
expandAlias tm t = 
    let (ps, as, ta, b) = expandAliases tm t in
       if b && length ps == length as then
	  (subst (Map.fromList (zip ps $ reverse as)) ta, b)
	  else (ta, b)

expandAliases :: TypeMap -> Type -> ([TypeArg], [Type], Type, Bool)
expandAliases tm t@(TypeName i _ _) =
       case Map.lookup i tm of 
            Just (TypeInfo _ _ _ 
		  (AliasTypeDefn (TypeScheme l (_ :=> ts) _))) ->
		     (l, [], ts, True)
	    Just (TypeInfo _ _ _
		  (Supertype _ (TypeScheme l (_ :=> ts) _) _)) ->
		     (l, [], ts, True)
	    _ -> ([], [], t, False)

expandAliases tm (TypeAppl t1 t2) =
    let (ps, as, ta, b) = expandAliases tm t1 
	(t3, b2) = expandAlias tm t2
	in if b then 
	  (ps, t3:as, ta, b)  -- reverse later on
	  else ([], [], TypeAppl t1 t3, b2)

expandAliases tm (FunType  t1 a t2 ps) =
    let (t3, b1) = expandAlias tm t1 
	(t4, b2) = expandAlias tm t2
	in ([], [], FunType  t3 a t4 ps, b1 || b2)

expandAliases tm (ProductType ts ps) =
    let tls = map (expandAlias tm) ts 
	in ([], [], ProductType (map fst tls) ps, any snd tls)

expandAliases tm (LazyType t ps) =
    let (newT, b) = expandAlias tm t 
	in ([], [], LazyType newT ps, b)

expandAliases tm (KindedType t k ps) =
    let (newT, b) = expandAlias tm t 
	in ([], [], KindedType newT k ps, b)

expandAliases _ t = ([], [], t, False)
