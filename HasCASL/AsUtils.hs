{- |
Module      :  $Header$
Copyright   :  (c) Christian Maeder and Uni Bremen 2003 
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  maeder@tzi.de
Stability   :  experimental
Portability :  portable 

utility functions and computations of meaningful positions for
   various data types of the abstract syntax
-}

module HasCASL.AsUtils where

import HasCASL.As
import HasCASL.PrintAs()
import Common.Id
import Common.PrettyPrint
import qualified Common.Lib.Set as Set

{- | decompose an 'ApplTerm' into an application of an operation and a
     list of arguments -}
getAppl :: Term -> Maybe (Id, TypeScheme, [Term])
getAppl = thrdM reverse . getRevAppl
    where
    thrdM :: (c -> c) -> Maybe (a, b, c) -> Maybe (a, b, c)
    thrdM f = fmap ( \ (a, b, c) -> (a, b, f c))
    getRevAppl :: Term -> Maybe (Id, TypeScheme, [Term])
    getRevAppl t = case t of 
        TypedTerm trm q _ _ -> case q of 
            InType -> Nothing
            _ -> getRevAppl trm 
        QualOp _ (InstOpId i _ _) sc _ -> Just (i, sc, [])
        QualVar (VarDecl v ty _ _) -> Just (v, simpleTypeScheme ty, [])
        ApplTerm t1 t2 _ -> thrdM (t2:) $ getRevAppl t1
        _ -> Nothing

-- | extract bindings from an analysed pattern
extractVars :: Pattern -> [VarDecl]
extractVars pat = 
    case pat of
    QualVar vd -> getVd vd
    ApplTerm p1 p2 _ -> 
         extractVars p1 ++ extractVars p2
    TupleTerm pats _ -> concatMap extractVars pats
    TypedTerm p _ _ _ -> extractVars p
    AsPattern v p2 _ -> getVd v ++ extractVars p2
    ResolvedMixTerm _ pats _ -> concatMap extractVars pats
    _ -> []
    where getVd vd@(VarDecl v _ _ _) = if showId v "" == "_" then [] else [vd]

-- | construct term from id
mkOpTerm :: Id -> TypeScheme -> Term
mkOpTerm i sc = QualOp Op (InstOpId i [] []) sc []

-- | bind a term
mkForall :: [GenVarDecl] -> Term -> Term
mkForall vl f = if null vl then f else QuantifiedTerm Universal vl f []

-- | construct application with curried arguments
mkApplTerm :: Term -> [Term] -> Term
mkApplTerm = foldl ( \ t a -> ApplTerm t a []) 

-- | make function arrow partial after some arguments
addPartiality :: [a] -> Type -> Type
addPartiality args t = case args of 
        [] -> LazyType t []
        _ : rs -> case t of 
           FunType t1 a t2 ps -> if null rs then FunType t1 PFunArr t2 ps 
               else FunType t1 a (addPartiality rs t2) ps
           _ -> error "addPartiality"

-- | get the type of a constructor for printing (kinds may be wrong)
getSimpleConstrType :: Id -> [TypeArg] -> Partiality -> [Type] -> Type
getSimpleConstrType i is p ts = (case p of 
     Total -> id 
     Partial -> addPartiality ts) $
                       foldr ( \ c r -> FunType c FunArr r [] ) 
                             (mkTypeAppl (mkTypeName i) $ 
                                 map (mkTypeName . getTypeVar) is) ts

-- | get the type variable
getTypeVar :: TypeArg -> Id
getTypeVar(TypeArg v _ _ _ _ _) = v

-- | construct application left-associative
mkTypeAppl :: Type -> [Type] -> Type
mkTypeAppl = foldl ( \ c a -> TypeAppl c a)

-- | get the kind of an analyzed type variable
toKind :: VarKind -> Kind
toKind vk = case vk of
    VarKind k -> k
    Downset t -> case t of 
        KindedType _ k _ -> k
        _ -> error "toKind: Downset"
    MissingKind -> error "toKind: Missing"

-- | generate a comparison string 
expected :: PrettyPrint a => a -> a -> String
expected a b = 
    "\n  expected: " ++ showPretty a 
    "\n     found: " ++ showPretty b "\n" 

-- * compute better positions

posOfVars :: Vars -> [Pos]
posOfVars vr = 
    case vr of 
    Var v -> posOfId v
    VarTuple _ ps -> ps

posOfTypeArg :: TypeArg -> [Pos]
posOfTypeArg (TypeArg t _ _ _ _ ps) = firstPos [t] ps

posOfTypePattern :: TypePattern -> [Pos]
posOfTypePattern pat = 
    case pat of
    TypePattern t _ _ -> posOfId t
    TypePatternToken t -> tokPos t
    MixfixTypePattern ts -> posOf ts
    BracketTypePattern _ ts ps -> firstPos ts ps
    TypePatternArg (TypeArg t _ _ _ _ _) _ -> posOfId t

posOfType :: Type -> [Pos]
posOfType ty = 
    case ty of
    TypeName i _ _ -> posOfId i
    TypeAppl t1 t2 -> concatMap posOfType [t1, t2]
    ExpandedType t1 t2 -> concatMap posOfType [t1, t2]
    TypeToken t -> tokPos t
    BracketType _ ts ps -> concatMap posOfType ts ++ ps
    KindedType t _ ps -> posOfType t ++ ps
    MixfixType ts -> concatMap posOfType ts
    LazyType t ps -> posOfType t ++ ps
    ProductType ts ps -> concatMap posOfType ts ++ ps
    FunType t1 _ t2 ps -> concatMap posOfType [t1, t2] ++ ps

posOfTerm :: Term -> [Pos]
posOfTerm trm =
    case trm of
    QualVar v -> posOfVarDecl v
    QualOp _ (InstOpId i _ ps) _ qs -> firstPos [i] (ps++qs) 
    ResolvedMixTerm i _ _ -> posOfId i
    ApplTerm t1 t2 ps -> firstPos [t1, t2] ps
    TupleTerm ts ps -> firstPos ts ps 
    TypedTerm t _ _ ps -> firstPos [t] ps 
    QuantifiedTerm _ _ t ps -> firstPos [t] ps 
    LambdaTerm _ _ t ps -> firstPos [t] ps 
    CaseTerm t _ ps -> firstPos [t] ps 
    LetTerm _ _ t ps -> firstPos [t] ps
    TermToken t -> tokPos t
    MixTypeTerm _ t ps -> firstPos [t] ps
    MixfixTerm ts -> posOf ts
    BracketTerm _ ts ps -> firstPos ts ps 
    AsPattern v _ ps -> firstPos [v] ps

posOfVarDecl :: VarDecl -> [Pos]
posOfVarDecl (VarDecl v _ _ ps) = firstPos [v] ps

instance PosItem a => PosItem [a] where
    get_pos = concatMap get_pos 

instance PosItem a => PosItem (a, b) where
    get_pos (a, _) = get_pos a

instance PosItem a => PosItem (Set.Set a) where
    get_pos = get_pos . Set.toList
