{-# OPTIONS_GHC -fwarn-missing-signatures #-}
{-# OPTIONS_GHC -fno-warn-tabs #-}
module Final where

import Prelude hiding (LT, GT, EQ)
import System.IO
import Base
import Data.Maybe
import Data.List
import Operators
import RecursiveFunctionsAST
import RecursiveFunctionsParse
import Test.Hspec
import Control.Exception (evaluate,AsyncException(..))
-- Uncomment the following if you choose to do Problem 3.
{-
import System.Environment
import System.Directory (doesFileExist)
import System.Process
import System.Exit
import System.Console.Haskeline
--        ^^ This requires installing haskeline: cabal update && cabal install haskeline
-}


--
-- The parsing function, parseExp :: String -> Exp, is defined for you.
--
exp1, exp2, exp3, exp4, exp5, exp6, facvar, facrec :: Exp

facvar   = parseExp ("var fac = function(n) { if (n==0) 1 else n * fac(n-1) };" ++
                   "fac(5)")  --should throw error because it's unbound

facrec   = parseExp ("rec fac = function(n) { if (n==0) 1 else n * fac(n-1) };" ++
                   "fac(5)")

exp1     = parseExp "var a = 3; var b = 8; var a = b, b = a; a + b"
exp2     = parseExp "var a = 3; var b = 8; var a = b; var b = a; a + b"
exp3     = parseExp "var a = 2, b = 7; (var m = 5 * a, n = b - 1; a * n + b / m) + a"
exp4     = parseExp "var a = 2, b = 7; (var m = 5 * a, n = m - 1; a * n + b / m) + a"         
-- N.b.,                                                  ^^^ is a free occurence of m (by Rule 2)
exp5 = parseExp "var m = 42, n = m; n + m"
exp6 = parseExp ("var n = 1, m = n; a + b")

-----------------
-- The evaluation function for the recursive function language.
-----------------

eval :: Exp -> Env -> Value
eval (Literal v) env                = v
eval (Unary op a) env               = unary  op (eval a env)
eval (Binary op a b) env            = binary op (eval a env) (eval b env)
eval (If a b c) env                 = let BoolV test = eval a env
                                      in if test then  eval b env else eval c env
eval (Variable x) env               = fromJust x (lookup x env)
  where fromJust x (Just v)         = v
        fromJust x Nothing          = errorWithoutStackTrace ("Variable " ++ x ++ " unbound!")
eval (Function x body) env          = ClosureV x body env
-----------------------------------------------------------------
--eval (Declare x [(x,exp)] body) env = eval body newEnv         -- This clause needs to be changed.
 -- where newEnv = (x, eval exp env) : env    

--We used the discussion in class to complete this problem.
--The problem was separating the tuple, evaluating the second part, and then combining them together.
--the use of map comes in handy in this function as it 'maps' a function over a list.
--Unforunately, map only takes a function and a string, whereas eval takes a variable and an env.
--To solve this, we used Haskell's first class functions to create a function to handle the eval
--and then used that function inside map, in this case to satisfy maps' type.
eval (Declare decls body) env = eval body newEnv
  where vars = map fst decls
        testvar = map snd decls
        values = map eval' testvar
		where eval' x = eval x env
        newEnv = zip vars values ++ env                     
-----------------------------------------------------------------
eval (RecDeclare x exp body) env    = eval body newEnv
  where newEnv = (x, eval exp newEnv) : env
eval (Call fun arg) env = eval body newEnv
  where ClosureV x body closeEnv    = eval fun env
        newEnv = (x, eval arg env) : closeEnv
        
-- Use this function to run your eval solution.
execute :: Exp -> Value
execute exp = eval exp []
-- Example usage: execute exp1

{-

Hint: it may help to remember that:
   map :: (a -> b) -> [a] -> [b]
   concat :: [[a]] -> [a]
when doing the Declare case.

-}

freeByRule1 :: [String] -> Exp -> [String]
 

freeByRule1 seen (Literal _)           = []

freeByRule1 seen (Unary _ e)           = freeByRule1 seen e

freeByRule1 seen (Binary _ e1 e2)          = (freeByRule1 seen e1) ++ (freeByRule1 seen e2)

freeByRule1 seen (If e1 e2 e3)         = ((freeByRule1 seen e1) ++ (freeByRule1 seen e2)) ++ (freeByRule1 seen e3)

freeByRule1 seen (Variable x)          = if x `elem` seen then [] else [x]
{-
freeByRule1 seen (Declare decls body)  =

freeByRule1 seen (RecDeclare x e1 e2)  =

freeByRule1 seen (Function x e)        =

freeByRule1 seen (call e1 e2)          =
-}
-- FreeByRule2
-- Credit: Justin Hofer, MU CS Alumnus 

freeByRule2 :: [String] -> Exp -> [String]

 -- No variables in literals
freeByRule2 seen (Literal _)            = []
-- remove op, put back variable
freeByRule2 seen (Unary _ e)            = freeByRule2 seen e
-- remote op, put back 2 variables
freeByRule2 seen (Binary _ e1 e2)       = (freeByRule2 seen e1) ++ (freeByRule2 seen e2)
-- remove If and put back e's=
freeByRule2 seen (If e1 e2 e3)          = ((freeByRule2 seen e1) ++ (freeByRule2 seen e2)) ++ (freeByRule2 seen e3)
-- Check if we've seen this element before. If not, its free!
freeByRule2 seen (Variable x)           = if x `elem` seen then [] else [x]
-- return all variables that were declared
freeByRule2 seen (Declare decls body)   = freeHelper2 seen (Declare decls body) []
-- Split declarations, and add to seen 
freeByRule2 seen (RecDeclare x e1 e2) = (freeByRule2 (x:seen) e1) ++ (freeByRule2 (x:seen) e2)
-- put back the body and add to seen
freeByRule2 seen (Function x e) = freeByRule2 (x:seen) e
-- mult expressions - split them
freeByRule2 seen (Call e1 e2) = (freeByRule2 seen e1) ++ (freeByRule2 seen e2)

-- helper func
freeHelper2 :: [String] -> Exp -> [String] -> [String]
-- get variable name, put back expression
-- check for more free variables
-- no more vars --> return accumulator
-- variable --> check if seen
--    not seen -> add to free list
-- add to seen if not free
freeHelper2 seen (Declare ((x, e1):xs) e2) acc  = (freeByRule2 seen e1) ++ (freeHelper2 seen (Declare xs e2) (x:acc))
--  nothing declared here
freeHelper2 seen (Declare [] e2) acc            = freeByRule2 (acc ++ seen) e2

--jotted these down from board in class. use these as a starting point

{-
free :: [String] -> Exp -> [String]
free seen (Literal _) 		= []
free seen (Unary _ e) 		= free
free seen (Binary _ e1 e1) 	=
free seen (If t e1 e2) 		=
free seen (Variabl x) 		=
free seen (Declare bs body) 	=
free seen (Call e1 e2) 		=

-}
---- Problem 3.

repl :: IO ()
repl = do
         putStr "RecFun> "
         iline <- getLine
         process iline

process :: String -> IO ()
process "quit" = return ()
process iline  = do
  putStrLn (show v ++ "\n")
  repl
   where e = parseExp iline
         v = eval e []



-- Test problems!
-- On problem one, I just used the values we knew the exp's returned as test cases. I figured if execute worked correctly on those, than the answers it returned on facvar and facrec were also correct so I then added it to those
test_prob1 :: IO()
test_prob1 = hspec $ do
	describe "Prob1 test case" $ do
		it "execute exp1 should return IntV 11" $ do
			execute exp1 `shouldBe` IntV 11
		it "execute exp2 should return IntV 16" $ do
			execute exp2 `shouldBe` IntV 16
		it "execute exp3 should return IntV 14" $ do
			execute exp3 `shouldBe` IntV 14
		it "execute exp4 should throw an Exception" $ do
			evaluate (execute exp4) `shouldThrow` anyException
		it "execute facvar should throw an exception" $ do
			evaluate (execute facvar) `shouldThrow` anyException
		it "execute facrec should return IntV 120" $ do
			execute facrec `shouldBe` IntV 120	


test_free2:: IO ()
test_free2 = hspec $ do
  describe "Prob2 from Final - Free Variables Rule 2" $ do

    context "var m = 42, n = m; n + m" $ do
      it "m should be a free variable" $ do
        (freeByRule2 [] exp5) `shouldBe` ["m"]
    
    context "var a = 2, b = 7; (var m = 5 * a, n = m - 1; a * n + b / m) + a" $ do
      it "m should be a free variable" $ do
        (freeByRule2 [] exp4) `shouldBe` ["m"]

    context "var fac = function(n) { if (n==0) 1 else n * fac(n-1) }; fac(5)" $ do
      it "fac should be a free variable" $ do
        (freeByRule2 [] facvar) `shouldBe` ["fac"]

    context "rec fac = function(n) { if (n==0) 1 else n * fac(n-1) }; fac(5)" $ do
      it "fac should not be a free variable" $ do
        (freeByRule2 [] facrec) `shouldBe` []
    
    context "var n = 1, m = n; a + b" $ do
      it "n, a, b should be free variables" $ do
        (freeByRule2 [] exp6) `shouldBe` ["n", "a", "b"]

