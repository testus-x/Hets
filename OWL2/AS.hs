{-# LANGUAGE DeriveDataTypeable #-}
{- |
Module      :  $Header$
Copyright   :  (c) Heng Jiang, Uni Bremen 2004-2007
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  non-portable(deriving Typeable)

This module defines all the data types for the functional style Syntax
of OWL 1.1.
It is modeled after the W3C document:
<http://www.w3.org/Submission/2006/SUBM-owl11-owl_specification-20061219/>
-}

module OWL2.AS where

import Common.Keywords
import Common.Id (GetRange)

import OWL.Keywords
import OWL.ColonKeywords
import qualified Data.Map as Map
import Data.Typeable

{- | full or abbreviated IRIs with a possible uri for the prefix
     or a local part following a hash sign -}
data QName = QN
  { namePrefix :: String
  -- ^ the name prefix part of a qualified name \"namePrefix:localPart\"
  , localPart :: String
  -- ^ the local part of a qualified name \"namePrefix:localPart\"
  , isFullIri :: Bool
  , namespaceUri :: String
  -- ^ the associated namespace uri (not printed)
  } deriving (Typeable, Show)

showQN :: QName -> String
showQN q = (if isFullIri q then showQI else showQU) q

-- | show QName as abbreviated iri
showQU :: QName -> String
showQU (QN pre local _ _) =
    if null pre then local else pre ++ ":" ++ local

-- | show QName in ankle brackets as full iris
showQI :: QName -> String
showQI = ('<' :) . (++ ">") . showQU

nullQName :: QName
nullQName = QN "" "" False ""

dummyQName :: QName
dummyQName = QN "http" "//www.dfki.de/sks/hets/ontology/unamed" True ""

mkQName :: String -> QName
mkQName s = nullQName { localPart = s }

instance Eq QName where
    p == q = compare p q == EQ

instance Ord QName where
  compare (QN p1 l1 b1 n1) (QN p2 l2 b2 n2) =
    if null n1 then
      if null n2 then compare (b1, p1, l1) (b2, p2, l2) else LT
    else if null n2 then GT else compare (b1, l1, n1) (b2, l2, n2)

type URI = QName
type URIreference = QName

-- | prefix -> localname
type Namespace = Map.Map String String

type AnnotationURI = URI
type OntologyURI = URI
type DatatypeURI = URI
type OwlClassURI = URI
type ObjectPropertyURI = URI
type DataPropertyURI = URI
type IndividualURI = URI
type ImportURI = URI

-- | Syntax of Ontologies
data Annotation =
  	Annotation AnnotationURI AnnotationBody
    deriving (Typeable, Show, Eq, Ord)

data AnnotationBody =
	OntIDorRef URI
       | AnnotationDataLiteral DataLiteral
       | AnnotationIndividual Individual
       
data PlainLiteral = PlainLiteral LexicalForm (Maybe LanguageTag)

data TypedLiteral = TypedLiteral LexicalForm URIreference

data DataLiteral = TypedData TypedLiteral | PlainData PlainLiteral



data OntologyFile = OntologyFile
  { namespaces :: Namespace
  , ontology :: Ontology
  } deriving (Typeable, Show, Eq, Ord)

instance GetRange OntologyFile

data Ontology = Ontology
  { uri :: OntologyURI
  , importsList :: [ImportURI]
  , annotationsList :: [Annotation]
  , axiomsList :: [Axiom]
  } deriving (Typeable, Show, Eq, Ord)

type OntologyMap = Map.Map String OntologyFile

data EntityType =
    Datatype
  | Class
  | ObjectProperty
  | DataProperty
  | AnnotationProperty
  | NamedIndividual
    deriving (Typeable, Enum, Bounded, Show, Read, Eq, Ord)

-- | Syntax of Entities
data Entity = Entity EntityType URI deriving (Typeable, Show, Eq, Ord)

instance GetRange Entity

entityTypes :: [EntityType]
entityTypes = [minBound .. maxBound]

-- | symbol items for hets
data SymbItems = SymbItems (Maybe EntityType) [URI]
    deriving (Typeable, Show, Eq)

data SymbMapItems = SymbMapItems (Maybe EntityType) [(URI, Maybe URI)]
    deriving (Typeable, Show, Eq)

-- | raw symbols
data RawSymb = ASymbol Entity | AnUri URI deriving (Typeable, Show, Eq, Ord)

type LexicalForm = String
type LanguageTag = String

data TypedOrUntyped = Typed URIreference | Untyped LanguageTag
    deriving (Typeable, Show, Eq, Ord)

cTypeS :: String
cTypeS = "^^"

-- | a lexical representation either with an "^^" URI (typed) or
-- an optional language tag starting with "\@" (untyped)
data Constant = Constant LexicalForm TypedOrUntyped
    deriving (Typeable, Show, Eq, Ord)

-- | Object and Data Property Expressions
type InverseObjectProperty = ObjectPropertyExpression

data ObjectPropertyExpression =
    OpURI ObjectPropertyURI
  | InverseOp InverseObjectProperty
    deriving (Typeable, Show, Eq, Ord)

type DataPropertyExpression = DataPropertyURI

-- | data type strings (some are not listed in the grammar)
datatypeKeys :: [String]
datatypeKeys =
  [ booleanS
  , dATAS
  , decimalS
  , floatS
  , integerS
  , negativeIntegerS
  , nonNegativeIntegerS
  , nonPositiveIntegerS
  , positiveIntegerS
  , stringS
  , universalS
  ]

-- | Syntax of Data Range
data DatatypeFacet =
    LENGTH
  | MINLENGTH
  | MAXLENGTH
  | PATTERN
  | MININCLUSIVE
  | MINEXCLUSIVE
  | MAXINCLUSIVE
  | MAXEXCLUSIVE
  | TOTALDIGITS
  | FRACTIONDIGITS
    deriving (Typeable, Show, Eq, Ord)

showFacet :: DatatypeFacet -> String
showFacet df = case df of
    LENGTH -> lengthS
    MINLENGTH -> minLengthS
    MAXLENGTH -> maxLengthS
    PATTERN -> patternS
    MININCLUSIVE -> lessEq
    MINEXCLUSIVE -> lessS
    MAXINCLUSIVE -> greaterEq
    MAXEXCLUSIVE -> greaterS
    TOTALDIGITS -> digitsS
    FRACTIONDIGITS -> fractionS

type RestrictionValue = Constant

data DataRange =
    DRDatatype DatatypeURI
  | DataComplementOf DataRange
  | DataOneOf [Constant] -- min. 1 constant
  | DatatypeRestriction DataRange [(DatatypeFacet, RestrictionValue)]
    deriving (Typeable, Show, Eq, Ord)

-- | Syntax of Entity Annotations
type AnnotationsForAxiom = Annotation
type AnnotationsForEntity = Annotation

data EntityAnnotation =
    EntityAnnotation [AnnotationsForAxiom] Entity [AnnotationsForEntity]
    deriving (Typeable, Show, Eq, Ord)

-- | Syntax of Classes

data CardinalityType = MinCardinality | MaxCardinality | ExactCardinality
    deriving (Show, Eq, Ord)

showCardinalityType :: CardinalityType -> String
showCardinalityType ty = case ty of
    MinCardinality -> minS
    MaxCardinality -> maxS
    ExactCardinality -> exactlyS

data JunctionType = UnionOf | IntersectionOf deriving (Show, Eq, Ord)

data QuantifierType = AllValuesFrom | SomeValuesFrom deriving (Show, Eq, Ord)

showQuantifierType :: QuantifierType -> String
showQuantifierType ty = case ty of
    AllValuesFrom -> onlyS
    SomeValuesFrom -> someS

data Cardinality a b = Cardinality CardinalityType Int a (Maybe b)
    deriving (Typeable, Show, Eq, Ord)

data Description =
    OWLClassDescription OwlClassURI
  | ObjectJunction JunctionType [Description]  -- min. 2 Descriptions
  | ObjectComplementOf Description
  | ObjectOneOf [IndividualURI]  -- min. 1 Individual
  | ObjectValuesFrom QuantifierType ObjectPropertyExpression Description
  | ObjectExistsSelf ObjectPropertyExpression
  | ObjectHasValue ObjectPropertyExpression IndividualURI
  | ObjectCardinality (Cardinality ObjectPropertyExpression Description)
  | DataValuesFrom
      QuantifierType DataPropertyExpression [DataPropertyExpression] DataRange
  | DataHasValue DataPropertyExpression Constant
  | DataCardinality (Cardinality DataPropertyExpression DataRange)
    deriving (Typeable, Show, Eq, Ord)

-- Axiom
type SubClass = Description
type SuperClass = Description

data SubObjectPropertyExpression =
    OPExpression ObjectPropertyExpression
  | SubObjectPropertyChain [ObjectPropertyExpression]
      -- ^ min. 2 ObjectPropertyExpression
    deriving (Typeable, Show, Eq, Ord)

type SourceIndividualURI = IndividualURI
type TargetIndividualURI = IndividualURI
type TargetValue = Constant

data Axiom = -- Annotations can be ignored
    PlainAxiom [Annotation] PlainAxiom
  | EntityAnno EntityAnnotation
    deriving (Typeable, Show, Eq, Ord)

instance GetRange Axiom

data EquivOrDisjoint = Equivalent | Disjoint deriving (Show, Eq, Ord)

showEquivOrDisjoint :: EquivOrDisjoint -> String
showEquivOrDisjoint ed = case ed of
    Equivalent -> equivalentToC
    Disjoint -> disjointWithC

data ObjDomainOrRange = ObjDomain | ObjRange deriving (Show, Eq, Ord)

showObjDomainOrRange :: ObjDomainOrRange -> String
showObjDomainOrRange dr = case dr of
    ObjDomain -> domainC
    ObjRange -> rangeC

data DataDomainOrRange = DataDomain Description | DataRange DataRange
    deriving (Typeable, Show, Eq, Ord)

data Character =
    Functional
  | InverseFunctional
  | Reflexive
  | Irreflexive
  | Symmetric
  | Asymmetric
  | Antisymmetric
  | Transitive
    deriving (Typeable, Enum, Bounded, Show, Eq, Ord)

data SameOrDifferent = Same | Different deriving (Show, Eq, Ord)

showSameOrDifferent :: SameOrDifferent -> String
showSameOrDifferent sd = case sd of
    Same -> sameAsC
    Different -> differentFromC

data PositiveOrNegative = Positive | Negative deriving (Show, Eq, Ord)

data Assertion a b = Assertion a PositiveOrNegative SourceIndividualURI b
    deriving (Typeable, Show, Eq, Ord)

data PlainAxiom =
    SubClassOf SubClass SuperClass
  | EquivOrDisjointClasses EquivOrDisjoint [Description] -- min. 2 desc.
  | DisjointUnion OwlClassURI [Description] -- min. 2 desc.
  | SubObjectPropertyOf SubObjectPropertyExpression ObjectPropertyExpression
  | EquivOrDisjointObjectProperties EquivOrDisjoint [ObjectPropertyExpression]
                                  -- min. 2  ObjectPropertyExpression
  | ObjectPropertyDomainOrRange ObjDomainOrRange ObjectPropertyExpression
    Description
  | InverseObjectProperties ObjectPropertyExpression ObjectPropertyExpression
  | ObjectPropertyCharacter Character ObjectPropertyExpression
  | SubDataPropertyOf DataPropertyExpression DataPropertyExpression
  | EquivOrDisjointDataProperties EquivOrDisjoint [DataPropertyExpression]
                                  -- min. 2 DataPropertyExpressions
  | DataPropertyDomainOrRange DataDomainOrRange DataPropertyExpression
  | FunctionalDataProperty DataPropertyExpression
  | SameOrDifferentIndividual SameOrDifferent [IndividualURI]  -- min. 2 ind.
  | ClassAssertion IndividualURI Description
  | ObjectPropertyAssertion
    (Assertion ObjectPropertyExpression TargetIndividualURI)
  | DataPropertyAssertion
    (Assertion DataPropertyExpression TargetValue)
  | Declaration Entity
    deriving (Typeable, Show, Eq, Ord)

emptyOntologyFile :: OntologyFile
emptyOntologyFile = OntologyFile Map.empty emptyOntology

emptyOntology :: Ontology
emptyOntology = Ontology nullQName [] [] []

isEmptyOntologyFile :: OntologyFile -> Bool
isEmptyOntologyFile (OntologyFile ns onto) =
    Map.null ns && isEmptyOntology onto

isEmptyOntology :: Ontology -> Bool
isEmptyOntology (Ontology (QN _ l _ n) annoList impList axioms) =
    null l && null n && null annoList && null impList && null axioms