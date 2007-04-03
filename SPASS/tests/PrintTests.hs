import Test.HUnit
import SPASS.Sign
import SPASS.Print

import Common.AS_Annotation
import Common.DocUtils

toTestFormula :: SPTerm -> SPFormula
toTestFormula = makeNamed "testFormula"

printProblemTest = TestList [
  TestLabel "problem" (TestCase (assertEqual "" expected actual))
  ]
  where
    expected = "begin_problem(testproblem).\n" ++ descr_expected ++ "\n" ++ logical_part_expected ++ "\nend_problem."
    descr_expected = "list_of_descriptions.\nname({* testdesc *}).\nauthor({* testauthor *}).\nstatus(unknown).\ndescription({* Just a test. *}).\nend_of_list."
    logical_part_expected = "list_of_symbols.\nfunctions[(foo,1),\n"++ (replicate (length "functions[") ' ') ++ "bar].\nend_of_list.\nlist_of_declarations.\nsubsort(a,b).\nsort a generated by [genA].\nend_of_list.\nlist_of_formulae(axioms).\nformula(equal(a,a),testformula).\nend_of_list.\nlist_of_formulae(conjectures).\nformula(equal(a,a),testformula).\nformula(equal(a,a),testformula).\nend_of_list."
    actual = showDoc (SPProblem {identifier= "testproblem", description= descr, logicalPart= logical_part}) ""
    descr = SPDescription {name="testdesc", author="testauthor", version=Nothing, logic=Nothing, status=SPStateUnknown, desc="Just a test.", date=Nothing}
    logical_part = SPLogicalPart {symbolList= Just $ SPSymbolList {functions= syms, predicates= [], sorts= [], operators= [], quantifiers=[]}, declarationList=[SPSubsortDecl {sortSymA="a", sortSymB="b"}, SPGenDecl {sortSym="a", freelyGenerated=False, funcList=["genA"]}], formulaLists= [SPFormulaList {originType= SPOriginAxioms, formulae= [(toTestFormula SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]})]},SPFormulaList {originType= SPOriginConjectures, formulae= [(toTestFormula SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]}), (toTestFormula SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]})]}]}
    syms = [SPSignSym {sym="foo", arity=1}, SPSimpleSignSym "bar"]

printLogicalPartTest = TestList [
  TestLabel "logical_part" (TestCase (assertEqual "" expected actual))
  ]
  where
    expected = "list_of_symbols.\nfunctions[(foo,1),\n"++ (replicate (length "functions[") ' ') ++ "bar].\nend_of_list.\nlist_of_declarations.\nsubsort(a,b).\nsort a generated by [genA].\nend_of_list.\nlist_of_formulae(axioms).\nformula(equal(a,a),testformula).\nend_of_list.\nlist_of_formulae(conjectures).\nformula(equal(a,a),testformula).\nformula(equal(a,a),testformula).\nend_of_list."
    actual = showDoc (SPLogicalPart {symbolList= Just $ SPSymbolList {functions= syms, predicates= [], sorts= [], operators= [], quantifiers=[]}, declarationList=[SPSubsortDecl {sortSymA="a", sortSymB="b"}, SPGenDecl {sortSym="a", freelyGenerated=False, funcList=["genA"]}], formulaLists= [SPFormulaList {originType= SPOriginAxioms, formulae= [(toTestFormula SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]})]},SPFormulaList {originType= SPOriginConjectures, formulae= [(toTestFormula SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]}), (toTestFormula SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]})]}]}) ""
    syms = [SPSignSym {sym="foo", arity=1}, SPSimpleSignSym "bar"]

printSymbolListTest = TestList [
  TestLabel "sym_list_functions" (TestCase (assertEqual "" ("list_of_symbols.\nfunctions[(foo,1),\n"++ (replicate (length "functions[") ' ') ++ "bar].\nend_of_list.") (showDoc (SPSymbolList {functions= syms, predicates= [], sorts= [], operators= [], quantifiers=[]}) ""))),
  TestLabel "sym_list_predicates" (TestCase (assertEqual "" ("list_of_symbols.\npredicates[(foo,1),\n"++ (replicate (length "predicates[") ' ') ++ "bar].\nend_of_list.") (showDoc (SPSymbolList {functions= [], predicates= syms, sorts= [], operators= [], quantifiers=[]}) ""))),
  TestLabel "sym_list_sorts" (TestCase (assertEqual "" ("list_of_symbols.\nsorts[(foo,1),\n"++ (replicate (length "sorts[") ' ') ++ "bar].\nend_of_list.") (showDoc (SPSymbolList {functions= [], predicates= [], sorts= syms, operators= [], quantifiers=[]}) ""))),
  TestLabel "sym_list_operators" (TestCase (assertEqual "" ("list_of_symbols.\noperators[(foo,1),\n"++ (replicate (length "operators[") ' ') ++ "bar].\nend_of_list.") (showDoc (SPSymbolList {functions= [], predicates= [], sorts= [], operators= syms, quantifiers=[]}) ""))),
  TestLabel "sym_list_quantifiers" (TestCase (assertEqual "" ("list_of_symbols.\nquantifiers[(foo,1),\n"++ (replicate (length "quantifiers[") ' ') ++ "bar].\nend_of_list.") (showDoc (SPSymbolList {functions= [], predicates= [], sorts= [], operators= [], quantifiers=syms}) "")))
  ]
  where
    syms = [SPSignSym {sym="foo", arity=1}, SPSimpleSignSym "bar"]

printSignSymTest = TestList [
  TestLabel "sign_sym" (TestCase (assertEqual "" "(a,1)" (showDoc (SPSignSym {sym="a", arity=1}) ""))),
  TestLabel "simple_sign_sym" (TestCase (assertEqual "" "b" (showDoc (SPSimpleSignSym "b") "")))
  ]

printDeclarationTest = TestList [
  TestLabel "subsort_decl" (TestCase (assertEqual "" "subsort(a,b)." (showDoc (SPSubsortDecl {sortSymA="a", sortSymB="b"}) ""))),
  TestLabel "term_decl" (TestCase (assertEqual "" "forall([a,b],implies(a,b))." (showDoc (SPTermDecl {termDeclTermList= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "b")], termDeclTerm= SPComplexTerm {symbol= SPImplies, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "b")]}}) ""))),
  TestLabel "simple_term_decl" (TestCase (assertEqual "" "asimpletestterm." (showDoc (SPSimpleTermDecl (SPSimpleTerm (SPCustomSymbol "asimpletestterm"))) ""))),
  TestLabel "pred_decl1" (TestCase (assertEqual "" "predicate(a,b)." (showDoc (SPPredDecl {predSym="a", sortSyms=["b"]}) ""))),
  TestLabel "pred_decl2" (TestCase (assertEqual "" "predicate(a,b,c)." (showDoc (SPPredDecl {predSym="a", sortSyms=["b","c"]}) ""))),
  TestLabel "gen_decl1" (TestCase (assertEqual "" "sort a generated by [genA]." (showDoc (SPGenDecl {sortSym="a", freelyGenerated=False, funcList=["genA"]}) ""))),
  TestLabel "gen_decl2" (TestCase (assertEqual "" "sort a generated by [genA,genA2]." (showDoc (SPGenDecl {sortSym="a", freelyGenerated=False, funcList=["genA", "genA2"]}) ""))),
  TestLabel "gen_decl3" (TestCase (assertEqual "" "sort a freely generated by [genA]." (showDoc (SPGenDecl {sortSym="a", freelyGenerated=True, funcList=["genA"]}) ""))),
  TestLabel "gen_decl4" (TestCase (assertEqual "" "sort a freely generated by [genA,genA2]." (showDoc (SPGenDecl {sortSym="a", freelyGenerated=True, funcList=["genA", "genA2"]}) ""))),
  TestLabel "gen_decl5" (TestCase (assertEqual "" "sort a freely generated by [genA,genA2,genA3]." (showDoc (SPGenDecl {sortSym="a", freelyGenerated=True, funcList=["genA", "genA2", "genA3"]}) "")))
  ]

printFormulaListTest = TestList [
  TestLabel "formula_list0" (TestList [
    TestCase (assertEqual "" "list_of_formulae(axioms).\nend_of_list." (showDoc (SPFormulaList {originType= SPOriginAxioms, formulae= []}) "")),
    TestCase (assertEqual "" "list_of_formulae(conjectures).\nend_of_list." (showDoc (SPFormulaList {originType= SPOriginConjectures, formulae= []}) ""))]),
  TestLabel "formula_list1" (TestList [
    TestCase (assertEqual "" "list_of_formulae(axioms).\nformula(equal(a,a),testformula).\nend_of_list." (showDoc (SPFormulaList {originType= SPOriginAxioms, formulae= [(toTestFormula SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]})]}) "")),
    TestCase (assertEqual "" "list_of_formulae(conjectures).\nformula(equal(a,a),testformula).\nend_of_list." (showDoc (SPFormulaList {originType= SPOriginConjectures, formulae= [(toTestFormula SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]})]}) ""))]),
  TestLabel "formula_list2" (TestList [
    TestCase (assertEqual "" "list_of_formulae(axioms).\nformula(equal(a,a),testformula).\nformula(equal(a,a),testformula).\nend_of_list." (showDoc (SPFormulaList {originType= SPOriginAxioms, formulae= [(toTestFormula SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]}), (toTestFormula SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]})]}) "")),
    TestCase (assertEqual "" "list_of_formulae(conjectures).\nformula(equal(a,a),testformula).\nformula(equal(a,a),testformula).\nend_of_list." (showDoc (SPFormulaList {originType= SPOriginConjectures, formulae= [(toTestFormula SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]}){senName= "testformula"}, (toTestFormula SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]})]}) ""))])
  ]

printFormulaTest = TestList [
  TestLabel "formula" (TestCase (assertEqual "" "formula(equal(a,a),testformula)" (show (printFormula ((toTestFormula SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]}))))))
  ]

printTermTest = TestList [
  -- empty term list not allowed!
  TestLabel "quant_term1" (TestCase (assertEqual "" "forall([a],equal(a,a))" (showDoc (SPQuantTerm {quantSym= SPForall, variableList= [SPSimpleTerm (SPCustomSymbol "a")], qFormula= SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]}}) ""))),
  TestLabel "quant_term2" (TestCase (assertEqual "" "forall([a,a],equal(a,a))" (showDoc (SPQuantTerm {quantSym= SPForall, variableList= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")], qFormula= SPComplexTerm {symbol= SPEqual, arguments= [SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "a")]}}) ""))),
  TestLabel "simple_term" (TestCase (assertEqual "" "testsymbol" (showDoc (SPSimpleTerm (SPCustomSymbol "testsymbol")) ""))),
  -- empty arguments list not allowed!
  TestLabel "complex_term1" (TestCase (assertEqual "" "test(a)" (showDoc (SPComplexTerm {symbol= SPCustomSymbol "test", arguments=[SPSimpleTerm (SPCustomSymbol "a")]}) ""))),
  TestLabel "complex_term2" (TestCase (assertEqual "" "implies(a,b)" (showDoc (SPComplexTerm {symbol= SPImplies, arguments=[SPSimpleTerm (SPCustomSymbol "a"), SPSimpleTerm (SPCustomSymbol "b")]}) "")))]

printQuantSymTest = TestList [
  TestLabel "forall_sym" (TestCase (assertEqual "" "forall" (showDoc SPForall ""))),
  TestLabel "exists_sym" (TestCase (assertEqual "" "exists" (showDoc SPExists ""))),
  TestLabel "custom_sym" (TestCase (assertEqual "" "custom" (showDoc (SPCustomQuantSym "custom") "")))]

printSymTest = TestList [
  TestLabel "equal_sym" (TestCase (assertEqual "" "equal" (showDoc SPEqual ""))),
  TestLabel "true_sym" (TestCase (assertEqual "" "true" (showDoc SPTrue ""))),
  TestLabel "false_sym" (TestCase (assertEqual "" "false" (showDoc SPFalse""))),
  TestLabel "or_sym" (TestCase (assertEqual "" "or" (showDoc SPOr ""))),
  TestLabel "and_sym" (TestCase (assertEqual "" "and" (showDoc SPAnd ""))),
  TestLabel "not_sym" (TestCase (assertEqual "" "not" (showDoc SPNot ""))),
  TestLabel "implies_sym" (TestCase (assertEqual "" "implies" (showDoc SPImplies ""))),
  TestLabel "implied_sym" (TestCase (assertEqual "" "implied" (showDoc SPImplied ""))),
  TestLabel "equiv_sym" (TestCase (assertEqual "" "equiv" (showDoc SPEquiv""))),
  TestLabel "custom_sym" (TestCase (assertEqual "" "custom" (showDoc (SPCustomSymbol "custom") "")))]

printDescriptionTest = TestList [
  TestLabel "description1" (TestCase (assertEqual "" "list_of_descriptions.\nname({* testdesc *}).\nauthor({* testauthor *}).\nstatus(unknown).\ndescription({* Just a test. *}).\nend_of_list." (showDoc (SPDescription {name="testdesc", author="testauthor", version=Nothing, logic=Nothing, status=SPStateUnknown, desc="Just a test.", date=Nothing}) ""))),
  TestLabel "description2" (TestCase (assertEqual "" "list_of_descriptions.\nname({* testdesc *}).\nauthor({* testauthor *}).\nversion({* 0.1 *}).\nlogic({* logic description *}).\nstatus(unknown).\ndescription({* Just a test. *}).\ndate({* today *}).\nend_of_list." (showDoc (SPDescription {name="testdesc", author="testauthor", version=Just "0.1", logic=Just "logic description", status=SPStateUnknown, desc="Just a test.", date=Just "today"}) "")))
  ]

printLogStateTest = TestList [
  TestLabel "state_satisfiable" (TestCase (assertEqual "" "satisfiable" (showDoc SPStateSatisfiable ""))),
  TestLabel "state_unsatisfiable" (TestCase (assertEqual "" "unsatisfiable" (showDoc SPStateUnsatisfiable ""))),
  TestLabel "state_unkwown" (TestCase (assertEqual "" "unknown" (showDoc SPStateUnknown "")))]

tests = TestList [
  printProblemTest,
  printLogicalPartTest,
  printSymbolListTest,
  printSignSymTest,
  printDeclarationTest,
  printFormulaListTest,
  printFormulaTest,
  printTermTest,
  printQuantSymTest,
  printSymTest,
  printDescriptionTest,
  printLogStateTest]

main :: IO ()
main = do
  c <-runTestTT tests
  return ()
