{- |
Module      :  $Id$
Description :  Parser for CspCASL processes
Copyright   :  (c)
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  a.m.gimblett@swan.ac.uk
Stability   :  experimental
Portability :

Parser for CSP-CASL processes.

-}

module CspCASL.Parse_CspCASL_Process (
    channel_name,
    csp_casl_sort,
    csp_casl_process,
    event_set,
    process_name,
    var,
) where

import Text.ParserCombinators.Parsec (sepBy, try, (<|>))

import qualified CASL.Formula
import CASL.AS_Basic_CASL (SORT, VAR)
import Common.AnnoState (AParser, asKey, anSemi, colonT)
import Common.Id (simpleIdToId)
import Common.Keywords (ifS, thenS, elseS)
import Common.Lexer ((<<), commaSep1, commaT, cParenT, oParenT)
import Common.Token (parseId, sortId, varId)

import CspCASL.AS_CspCASL_Process
import CspCASL.CspCASL_Keywords

csp_casl_process :: AParser st PROCESS
csp_casl_process = conditional_process <|> parallel_process

conditional_process :: AParser st PROCESS
conditional_process = do asKey ifS
                         f <- formula
                         asKey thenS
                         p <- csp_casl_process
                         asKey elseS
                         q <- csp_casl_process
                         return (ConditionalProcess f p q)

parallel_process :: AParser st PROCESS
parallel_process = do cp <- choice_process
                      p <- parallel_process' cp
                      return p

parallel_process' :: PROCESS -> AParser st PROCESS
parallel_process' lp =
    do     asKey interleavingS
           rp <- choice_process
           p <- parallel_process' (Interleaving lp rp)
           return p
    <|> do asKey synchronousS
           rp <- choice_process
           p <- parallel_process' (SynchronousParallel lp rp)
           return p
    <|> do asKey general_parallel_openS
           es <- event_set
           asKey general_parallel_closeS
           rp <- choice_process
           p <- parallel_process' (GeneralisedParallel lp es rp)
           return p
    <|> do asKey alpha_parallel_openS
           les <- event_set
           asKey alpha_parallel_sepS
           res <- event_set
           asKey alpha_parallel_closeS
           rp <- choice_process
           p <- parallel_process' (AlphabetisedParallel lp les res rp)
           return p
    <|> return lp

choice_process :: AParser st PROCESS
choice_process = do sp <- sequence_process
                    p <- choice_process' sp
                    return p

choice_process' :: PROCESS -> AParser st PROCESS
choice_process' lp =
    do     asKey external_choiceS
           rp <- sequence_process
           p <- choice_process' (ExternalChoice lp rp)
           return p
    <|> do asKey internal_choiceS
           rp <- sequence_process
           p <- choice_process' (InternalChoice lp rp)
           return p
    <|> return lp

sequence_process :: AParser st PROCESS
sequence_process = do pp <- prefix_process
                      p <- sequence_process' pp
                      return p

sequence_process' :: PROCESS -> AParser st PROCESS
sequence_process' lp =
    do  anSemi
        rp <- prefix_process
        p <- sequence_process' (Sequential lp rp)
        return p
    <|> return lp

prefix_process :: AParser st PROCESS
prefix_process =
    do     asKey internal_prefixS
           v <- var
           colonT
           s <- csp_casl_sort
           asKey prefixS
           p <- prefix_process
           return (InternalPrefixProcess v s p)
    <|> do asKey external_prefixS
           v <- var
           colonT
           s <- csp_casl_sort
           asKey prefixS
           p <- prefix_process
           return (ExternalPrefixProcess v s p)
    <|> do e <- try (event << asKey prefixS)
           p <- prefix_process
           return (PrefixProcess e p)
    <|> hiding_renaming_process

hiding_renaming_process :: AParser st PROCESS
hiding_renaming_process = do pl <- parenthesised_or_primitive_process
                             p <- (hiding_renaming' pl)
                             return p

hiding_renaming' :: PROCESS -> AParser st PROCESS
hiding_renaming' lp =
    do     asKey hidingS
           es <- event_set
           p <- (hiding_renaming' (Hiding lp es))
           return p
    <|> do asKey renaming_openS
           rn <- renaming
           asKey renaming_closeS
           p <- (hiding_renaming' (RelationalRenaming lp rn))
           return p
    <|> return lp

parenthesised_or_primitive_process :: AParser st PROCESS
parenthesised_or_primitive_process =
    do     try oParenT
           p <- csp_casl_process
           cParenT
           return p
    <|> do n <- (try process_name)
           args <- procArgs
           return (NamedProcess n args)
    <|> do asKey runS
           oParenT
           es <- event_set
           cParenT
           return (Run es)
    <|> do asKey chaosS
           oParenT
           es <- event_set
           cParenT
           return (Chaos es)
    <|> do asKey divS
           return Div
    <|> do asKey skipS
           return Skip
    <|> do asKey stopS
           return Stop

process_name :: AParser st PROCESS_NAME
process_name = fmap simpleIdToId (varId csp_casl_keywords)

channel_name :: AParser st CHANNEL_NAME
channel_name = fmap simpleIdToId (varId csp_casl_keywords)

-- List of arguments to a named process
procArgs :: AParser st [EVENT]
procArgs = do try oParenT
              es <- commaSep1 event
              cParenT
              return es
           <|> return []

-- Sort IDs, excluding CspCasl keywords
csp_casl_sort :: AParser st SORT
csp_casl_sort = sortId csp_casl_keywords

event_set :: AParser st EVENT_SET
event_set = do     asKey chan_event_openS
                   cn <- channel_name
                   asKey chan_event_closeS
                   return (ChannelEvents cn)
            <|> do sort_id <- sortId csp_casl_keywords
                   return (EventSet sort_id)

-- Events may be simple CASL terms or channel send/receives.

event :: AParser st EVENT
event = try chan_send <|> try chan_recv <|> simple_event

chan_send :: AParser st EVENT
chan_send = do cn <- channel_name
               asKey chan_sendS
               t <- CASL.Formula.term csp_casl_keywords
               return (Send cn t)

chan_recv :: AParser st EVENT
chan_recv = do cn <- channel_name
               asKey chan_receiveS
               v <- var
               colonT
               s <- csp_casl_sort
               return (Receive cn v s)

simple_event :: AParser st EVENT
simple_event = do t <- CASL.Formula.term csp_casl_keywords
                  return (Event t)

-- Formulas are CASL formulas.  We make our own wrapper around them
-- however.

formula :: AParser st CSP_FORMULA
formula = do f <- CASL.Formula.formula csp_casl_keywords
             return (Formula f)

-- Primitive renaming is done using an operator name or a predicate
-- name.  They're both Ids.  Separation between operator or predicate
-- (or some other non-applicable Id) must be a static analysis
-- problem.

renaming :: AParser st RENAMING
renaming = (parseId csp_casl_keywords) `sepBy` commaT

-- Variables come from CASL/Hets.

var :: AParser st VAR
var = varId csp_casl_keywords
