%
% (c) The GRASP/AQUA Project, Glasgow University, 1993-2000
%
\section{Generate Java}

Name mangling for Java.
~~~~~~~~~~~~~~~~~~~~~~

Haskell has a number of namespaces. The Java translator uses
the standard Haskell mangles (see OccName.lhs), and some extra
mangles.

All names are hidden inside packages.

module name:
  - becomes a first level java package.
  - can not clash with java, because haskell modules are upper case,
     java default packages are lower case.

function names: 
  - these turn into classes
  - java keywords (eg. private) have the suffix "zdk" ($k) added.

data *types*
  - These have a base class, so need to appear in the 
    same name space as other object. for example data Foo = Foo
  - We add a postfix to types: "zdt" ($t)
  - Types are upper case, so never clash with keywords

data constructors
  - There are tWO classes for each Constructor
   (1) - Class with the payload extends the relevent datatype baseclass.
       - This class has the prefix zdw ($W)
   (2) - Constructor *wrapper* just use their own name.
    - Constructors are upper case, so never clash with keywords
    - So Foo would become 2 classes.
	* Foo		-- the constructor wrapper
	* zdwFoo	-- the worker, with the payload

\begin{code}
module JavaGen( javaGen ) where

import Java

import Literal	( Literal(..) )
import Id	( Id, isDataConId_maybe, isId, idName, isDeadBinder, idPrimRep )
import Name	( NamedThing(..), getOccString, isGlobalName 
		, nameModule )
import PrimRep  ( PrimRep(..) )
import DataCon	( DataCon, dataConRepArity, dataConRepArgTys, dataConId )
import qualified TypeRep
import qualified Type
import qualified CoreSyn
import CoreSyn	( CoreBind, CoreExpr, CoreAlt, CoreBndr,
		  Bind(..), Alt, AltCon(..), collectBinders, isValArg
		)
import CoreUtils( exprIsValue, exprIsTrivial )
import Module	( Module, moduleString )
import TyCon	( TyCon, isDataTyCon, tyConDataCons )
import Outputable

#include "HsVersions.h"

\end{code}


\begin{code}
javaGen :: Module -> [Module] -> [TyCon] -> [CoreBind] -> CompilationUnit

javaGen mod import_mods tycons binds
  = id {-liftCompilationUnit-} package
  where
    decls = [Import "haskell.runtime.*"] ++
	    [Import (moduleString mod) | mod <- import_mods] ++
	    concat (map javaTyCon (filter isDataTyCon tycons)) ++ 
	    concat (map javaTopBind binds)
    package = Package (moduleString mod) decls
\end{code}


%************************************************************************
%*									*
\subsection{Type declarations}
%*									*
%************************************************************************

\begin{code}
javaTyCon :: TyCon -> [Decl]
--  	public class List {}
--
--	public class $wCons extends List {
--		Object f1; Object f2
--	}
--	public class $wNil extends List {}

javaTyCon tycon 
  = tycon_jclass : concat (map constr_class constrs)
  where
    constrs = tyConDataCons tycon
    tycon_jclass_jname =  javaGlobTypeName tycon ++ "zdc"
    tycon_jclass = Class [Public] (shortName tycon_jclass_jname) [] [] []

    constr_class data_con
	= [ Class [Public] (shortName constr_jname) [tycon_jclass_jname] []
				(field_decls ++ [cons_meth,debug_meth])
	  ]
	where
	  constr_jname = javaConstrWkrName data_con
	  constr_jtype = javaConstrWkrType data_con

	  field_names  = constrToFields data_con
	  field_decls  = [ Field [Public] n Nothing 
			 | n <- field_names
			 ]

	  cons_meth    = mkCons (shortName constr_jname) field_names

	  debug_meth   = Method [Public] (Name "toString" stringType)
					 []
					 []
		       (  [ Declaration (Field [] txt Nothing) ]
		       ++ [ ExprStatement
				(Assign (Var txt)
					    (mkStr
						("( " ++ 
						  getOccString data_con ++ 
						  " ")
				       	     )
				)
			  ]
		       ++ [ ExprStatement
				(Assign (Var txt)
				   (Op (Var txt)
				        "+" 
				       (Op (Var n) "+" litSp)
				   )
				)
			  | n <- field_names
			  ]
		       ++ [ Return (Op (Var txt)
				        "+" 
				      (mkStr ")")
				   )
			  ]
		       )

	  litSp    = mkStr " "
	  txt      = Name "__txt" stringType
	 

mkNew :: Type -> [Expr] -> Expr
mkNew t@(PrimType primType) [] = error "new primitive???"
mkNew t@(Type _)            es = New t es Nothing
mkNew _                     _  = error "new with strange arguments"

constrToFields :: DataCon -> [Name]
constrToFields cons = 
	[ fieldName i t 
	| (i,t) <- zip [1..] (map javaTauType (dataConRepArgTys cons))
	]

mkCons :: TypeName -> [Name] -> Decl
mkCons name args = Constructor [Public] name
	[ Parameter [] n | n <- args ]
	[ ExprStatement (Assign 
			   (Access this n)
			   (Var n)
			 )
		    | n <- args ]

mkStr :: String -> Expr
mkStr str = Literal (StringLit str)
\end{code}

%************************************************************************
%*									*
\subsection{Bindings}
%*									*
%************************************************************************

\begin{code}
javaTopBind :: CoreBind -> [Decl]
javaTopBind (NonRec bndr rhs) = [java_top_bind bndr rhs]
javaTopBind (Rec prs) 	      = [java_top_bind bndr rhs | (bndr,rhs) <- prs]

java_top_bind :: Id -> CoreExpr -> Decl
-- 	public class f implements Code {
--	  public Object ENTER() { ...translation of rhs... }
--	}
java_top_bind bndr rhs
  = Class [Public] (shortName (javaGlobTypeName bndr)) 
		[] [codeName] [enter_meth]
  where
    enter_meth = Method [Public] enterName [vmArg] [excName] 
			(javaExpr vmRETURN rhs)
\end{code}


%************************************************************************
%*									*
\subsection{Expressions}
%*									*
%************************************************************************

\begin{code}
javaVar :: Id -> Expr
javaVar v | isGlobalName (idName v) = mkNew (javaGlobType v) []
	  | otherwise	  	    = Var (javaName v)

javaLit :: Literal.Literal -> Expr
javaLit (MachInt i)  = Literal (IntLit (fromInteger i))
javaLit (MachChar c) = Literal (CharLit c)             
javaLit other	     = pprPanic "javaLit" (ppr other)

javaExpr :: (Expr -> Expr) -> CoreExpr -> [Statement]
-- Generate code to apply the value of 
-- the expression to the arguments aleady on the stack
javaExpr r (CoreSyn.Var v)   = [Return (r (javaVar v))]
javaExpr r (CoreSyn.Lit l)   = [Return (r (javaLit l))]
javaExpr r (CoreSyn.App f a) = javaApp r f [a]
javaExpr r e@(CoreSyn.Lam _ _) = javaLam r (collectBinders e)
javaExpr r (CoreSyn.Case e x alts) = javaCase r e x alts
javaExpr r (CoreSyn.Let bind body) = javaBind bind ++ javaExpr r body
javaExpr r (CoreSyn.Note _ e)	 = javaExpr r e

javaCase :: (Expr -> Expr) -> CoreExpr -> Id -> [CoreAlt] -> [Statement]
-- 	case e of x { Nil      -> r1
--		      Cons p q -> r2 }
-- ==>
--	final Object x = VM.WHNF(...code for e...)
--	else if x instance_of Nil {
--		...translation of r1...
--	} else if x instance_of Cons {
--		final Object p = ((Cons) x).f1
--		final Object q = ((Cons) x).f2
--		...translation of r2...
--	} else return null

javaCase r e x alts
  =  [var [Final] (javaName x) (vmWHNF (javaArg e)),
      IfThenElse (map mk_alt alts) Nothing]
  where
     mk_alt (DEFAULT, [], rhs)   = (true, 	    Block (javaExpr r rhs))
     mk_alt (DataAlt d, bs, rhs) = (instanceOf x d, Block (bind_args d bs ++ javaExpr r rhs))
     mk_alt alt@(LitAlt lit, [], rhs) 
				 = (eqLit lit     , Block (javaExpr r rhs))
     mk_alt alt@(LitAlt _, _, _) = pprPanic "mk_alt" (ppr alt)


     eqLit (MachInt n) = Op (Literal (IntLit n))
			    "=="
			    (Var (javaName x))
     eqLit other       = pprPanic "eqLit" (ppr other)

     bind_args d bs = [var [Final] (javaName b) 
			   (Access (Cast (javaConstrWkrType d) (javaVar x)
				   ) f
			   )
		      | (b,f) <- filter isId bs 
				      `zip` (constrToFields d)
		      , not (isDeadBinder b)
		      ]

javaBind (NonRec x rhs)
{-
	x = ...rhs_x...
  ==>
	final Object x = new Thunk( new Code() { ...code for rhs_x... } )
-}
  = [var [Final] (javaLocName x objectType)
		 (newThunk (newCode (javaExpr vmRETURN rhs)))
    ]

javaBind (Rec prs)
{- 	rec { x = ...rhs_x...; y = ...rhs_y... }
  ==>
	class x implements Code {
	  Code x, y;
	  public Object ENTER() { ...code for rhs_x...}
	}
	...ditto for y...

	final x x_inst = new x();
	...ditto for y...

	final Thunk x = new Thunk( x_inst );
	...ditto for y...

	x_inst.x = x;
	x_inst.y = y;
	...ditto for y...
-}
  = (map mk_class prs) ++ (map mk_inst prs) ++ 
    (map mk_thunk prs) ++ concat (map mk_knot prs)
  where
    mk_class (b,r) = Declaration (Class [] class_name [] [codeName] stmts)
		   where
		     class_name = javaLocTypeName b
		     stmts = [Field [] (javaLocName b codeType) Nothing | (b,_) <- prs] ++
			     [Method [Public] enterName [vmArg] [excName] (javaExpr vmRETURN r)]	

    mk_inst (b,r) = var [Final] (javaInstName b)
			(mkNew (javaGlobType b) [])

    mk_thunk (b,r) = var [Final] (javaLocName b thunkType)
			 (New thunkType [Var (javaInstName b)] Nothing)

    mk_knot (b,_) = [ ExprStatement (Assign lhs rhs) 
		    | (b',_) <- prs,
		      let lhs = Access (Var (javaInstName b)) (javaName b'),
		      let rhs = Var (javaName b')
		    ]


-- We are needlessly 
javaLam :: (Expr -> Expr) -> ([CoreBndr], CoreExpr) -> [Statement]
javaLam r (bndrs, body)
  | null val_bndrs = javaExpr r body
  | otherwise
  =  vmCOLLECT (length val_bndrs) this
  ++ [var [Final] n (vmPOP t) | n@(Name _ t) <- val_bndrs]
  ++ javaExpr r body
  where
    val_bndrs = map javaName (filter isId bndrs)

javaApp :: (Expr -> Expr) -> CoreExpr -> [CoreExpr] -> [Statement]
javaApp r (CoreSyn.App f a) as = javaApp r f (a:as)
javaApp r (CoreSyn.Var f) as
  = case isDataConId_maybe f of {
	Just dc | length as == dataConRepArity dc
		-> 	-- Saturated constructors
		   [Return (New (javaGlobType f) (javaArgs as) Nothing)]
    ; other ->   -- Not a saturated constructor
	java_apply r (CoreSyn.Var f) as
    }
	
javaApp r f as = java_apply r f as

java_apply :: (Expr -> Expr) -> CoreExpr -> [CoreExpr] -> [Statement]
java_apply r f as = [ExprStatement (vmPUSH arg) | arg <- javaArgs as] ++ javaExpr r f
javaArgs :: [CoreExpr] -> [Expr]
javaArgs args = [javaArg a | a <- args, isValArg a]

javaArg :: CoreExpr -> Expr
javaArg (CoreSyn.Type t) = pprPanic "javaArg" (ppr t)
javaArg e | exprIsValue e || exprIsTrivial e = newCode (javaExpr id e)
	  | otherwise	 		     = newThunk (newCode (javaExpr id e))
\end{code}

%************************************************************************
%*									*
\subsection{Helper functions}
%*									*
%************************************************************************

\begin{code}
true, this :: Expr
this = Var thisName 
true = Var (Name "true" (PrimType PrimBoolean))

vmCOLLECT :: Int -> Expr -> [Statement]
vmCOLLECT 0 e = []
vmCOLLECT n e = [ExprStatement 
		    (Call varVM collectName
			[ Literal (IntLit (toInteger n))
			, e
			]
		    )
		]

vmPOP :: Type -> Expr 
vmPOP ty = Call varVM (Name ("POP" ++ suffix ty) ty) []

vmPUSH :: Expr -> Expr
vmPUSH e = Call varVM (Name ("PUSH" ++ suffix (exprType e)) void) [e]

vmRETURN :: Expr -> Expr
vmRETURN e = 
     case ty of
	PrimType _ -> Call varVM (Name ("RETURN" ++ suffix (exprType e))
				       valueType
				  ) [e]
	_ -> e
  where
	ty = exprType e

var :: [Modifier] -> Name -> Expr -> Statement
var ms field_name value = Declaration (Field ms field_name (Just value))

vmWHNF :: Expr -> Expr
vmWHNF e = Call varVM whnfName [e]

suffix :: Type -> String
suffix (PrimType t) = primName t
suffix _            = ""

primName :: PrimType -> String
primName PrimInt  = "int"
primName PrimChar = "char"
primName _         = error "unsupported primitive"

varVM :: Expr
varVM = Var vmName 

instanceOf :: Id -> DataCon -> Expr
instanceOf x data_con
  = InstanceOf (Var (javaName x)) (javaConstrWkrType data_con)

newCode :: [Statement] -> Expr
newCode [Return e] = e
newCode stmts	   = New codeType [] (Just [Method [Public] enterName [vmArg] [excName] stmts])

newThunk :: Expr -> Expr
newThunk e = New thunkType [e] Nothing

vmArg :: Parameter
vmArg = Parameter [Final] vmName
\end{code}

%************************************************************************
%*									*
\subsection{Haskell to Java Types}
%*									*
%************************************************************************

\begin{code}
exprType (Var (Name _ t)) = t
exprType (Literal lit)    = litType lit
exprType (Cast t _)       = t
exprType (New t _ _)      = t
exprType _                = error "can't figure out an expression type"

litType (IntLit i)    = PrimType PrimInt
litType (CharLit i)   = PrimType PrimChar
litType (StringLit i) = error "<string?>"
\end{code}

%************************************************************************
%*									*
\subsection{Name mangling}
%*									*
%************************************************************************

\begin{code}
codeName, excName, thunkName :: TypeName
codeName  = "haskell.runtime.Code"
thunkName = "haskell.runtime.Thunk"
excName   = "java.lang.Exception"

enterName, vmName,thisName,collectName, whnfName :: Name
enterName   = Name "ENTER"   objectType
vmName      = Name "VM"      vmType
thisName    = Name "this"    (Type "<this>")
collectName = Name "COLLECT" void
whnfName    = Name "WNNF"    objectType

fieldName :: Int -> Type -> Name	-- Names for fields of a constructor
fieldName n ty = Name ("f" ++ show n) ty

-- TODO: change to idToJavaName :: Id -> Name

javaLocName :: Id -> Type -> Name
javaLocName n t = Name (getOccString n) t

javaName :: Id -> Name
javaName n = if isGlobalName n'
	     then Name (javaGlobTypeName n)
		       (javaGlobType n)
	     else Name (getOccString n)
		       (Type "<loc?>")
  where
	     n' = getName n

-- TypeName's are always global
javaGlobTypeName :: NamedThing a => a -> TypeName
javaGlobTypeName n = (moduleString (nameModule n') ++ "." ++ getOccString n)
  where
	     n' = getName n

javaLocTypeName :: NamedThing a => a -> TypeName
javaLocTypeName n = (moduleString (nameModule n') ++ "." ++ getOccString n)
  where
	     n' = getName n

-- this is used for getting the name of a class when defining it.
shortName :: TypeName -> TypeName
shortName = reverse . takeWhile (/= '.') . reverse

-- The function that makes the constructor name
javaConstrWkrName :: DataCon -> TypeName
javaConstrWkrName con = javaGlobTypeName (dataConId con)

-- Makes x_inst for Rec decls
javaInstName :: NamedThing a => a -> Name
javaInstName n = Name (getOccString n ++ "_inst") (Type "<inst>")
\end{code}

%************************************************************************
%*									*
\subsection{Types and type mangling}
%*									*
%************************************************************************

\begin{code}
-- Haskell RTS types
codeType, thunkType, valueType :: Type
codeType   = Type codeName
thunkType  = Type thunkName
valueType  = Type "haskell.runtime.Value"
vmType     = Type "haskell.runtime.VMEngine"

-- Basic Java types
objectType, stringType :: Type
objectType = Type "java.lang.Object"
stringType = Type "java.lang.String"

void :: Type
void = PrimType PrimVoid

inttype :: Type
inttype = PrimType PrimInt

chartype :: Type
chartype = PrimType PrimChar

-- This is where we map from type to possible primitive
mkType "PrelGHC.Intzh"  = inttype
mkType "PrelGHC.Charzh" = chartype
mkType other            = Type other

-- This mapping a global haskell name (typically a function name)
-- to the name of the class that handles it.
-- The name must be global. So foo in module Test maps to (Type "Test.foo")
-- TODO: change to Id

javaGlobType :: NamedThing a => a -> Type
javaGlobType n | '.' `notElem` name
	       = error ("not using a fully qualified name for javaGlobalType: " ++ name)
	       | otherwise
	       = mkType name
  where name = javaGlobTypeName n

-- This takes an id, and finds the ids *type* (for example, Int, Bool, a, etc).
javaType :: Id -> Type
javaType id = case (idPrimRep id) of
		IntRep -> inttype
		_ -> if isGlobalName (idName id)
		     then Type (javaGlobTypeName id)
		     else objectType		-- TODO: ?? for now ??

-- This is used to get inside constructors, to find out the types
-- of the payload elements
javaTauType :: Type.TauType -> Type
javaTauType (TypeRep.TyConApp tycon _) = javaGlobType tycon
javaTauType (TypeRep.NoteTy _ t)       = javaTauType t
javaTauType _                          = objectType

-- The function that makes the constructor name
javaConstrWkrType :: DataCon -> Type
javaConstrWkrType con = Type (javaConstrWkrName con)
\end{code}

%************************************************************************
%*									*
\subsection{Class Lifting}
%*									*
%************************************************************************

This is a very simple class lifter. It works by carrying inwards a
list of bound variables (things that might need to be passed to a
lifted inner class). 
 * Any variable references is check with this list, and if it is
   bound, then it is not top level, external reference. 
 * This means that for the purposes of lifting, it might be free
   inside a lifted inner class.
 * We remember these "free inside the inner class" values, and 
   use this list (which is passed, via the monad, outwards)
   when lifting.

\begin{code}
{-
type Bound = [Name]
type Frees = [Name]

combine :: [Name] -> [Name] -> [Name]
combine []           names          = names
combine names        []             = names
combine (name:names) (name':names') 
	| name < name' = name  : combine names (name':names')
	| name > name' = name' : combine (name:names) names'
	| name == name = name  : combine names names'
	| otherwise    = error "names are not a total order"

both :: [Name] -> [Name] -> [Name]
both []           names          = []
both names        []             = []
both (name:names) (name':names') 
	| name < name' = both names (name':names')
	| name > name' = both (name:names) names'
	| name == name = name  : both names names'
	| otherwise    = error "names are not a total order"

combineEnv :: Env -> [Name] -> Env
combineEnv (Env bound env) new = Env (bound `combine` new) env

addTypeMapping :: Name -> Name -> [Name] -> Env -> Env
addTypeMapping origName newName frees (Env bound env) 
	= Env bound ((origName,(newName,frees)) : env)

-- This a list of bound vars (with types)
-- and a mapping from types (?) to (result * [arg]) pairs
data Env = Env Bound [(Name,(Name,[Name]))]

newtype LifterM a = 
  	LifterM { unLifterM ::
		     Name ->
		     Int -> ( a			-- *
			    , Frees		-- frees
			    , [Decl]		-- lifted classes
			    , Int		-- The uniqs
			    )
		}

instance Monad LifterM where
	return a = LifterM (\ n s -> (a,[],[],s))
	(LifterM m) >>= fn = LifterM (\ n s ->
	  case m n s of
	    (a,frees,lifted,s) 
	         -> case unLifterM (fn a) n s of
	 	     (a,frees2,lifted2,s) -> ( a
					     , combine frees frees2
					     , lifted ++ lifted2
					     , s)
	  )

access :: Env -> Name -> LifterM ()
access env@(Env bound _) name 
	| name `elem` bound = LifterM (\ n s -> ((),[name],[],s))
	| otherwise         = return ()

scopedName :: Name -> LifterM a -> LifterM a
scopedName name (LifterM m) =
   LifterM (\ _ s -> 
      case m name 1 of
	(a,frees,lifted,_) -> (a,frees,lifted,s)
      )

genAnonInnerClassName :: LifterM Name
genAnonInnerClassName = LifterM (\ n s ->
	( n ++ "$" ++ show s
	, []
	, []
	, s + 1
	)
    )

genInnerClassName :: Name -> LifterM Name
genInnerClassName name = LifterM (\ n s ->
	( n ++ "$" ++ name 
	, []
	, []
	, s
	)
    )

getFrees  :: LifterM a -> LifterM (a,Frees)
getFrees (LifterM m) = LifterM (\ n s ->
	case m n s of
	  (a,frees,lifted,n) -> ((a,frees),frees,lifted,n)
    )

rememberClass :: Decl -> LifterM ()
rememberClass decl = LifterM (\ n s -> ((),[],[decl],s))


liftCompilationUnit :: CompilationUnit -> CompilationUnit
liftCompilationUnit (Package name ds) = 
    Package name (concatMap liftCompilationUnit' ds)

liftCompilationUnit' :: Decl -> [Decl]
liftCompilationUnit' decl = 
    case unLifterM (liftDecls True (Env [] []) [decl]) [] 1 of
      (ds,_,ds',_) -> ds ++ ds'


-- The bound vars for the current class have
-- already be captured before calling liftDecl,
-- because they are in scope everywhere inside the class.

liftDecl :: Bool -> Env -> Decl -> LifterM Decl
liftDecl = \ top env decl ->
  case decl of
    { Import n -> return (Import n)
    ; Field mfs t n e -> 
      do { e <- liftMaybeExpr env e
	 ; return (Field mfs (liftType env t) n e)
	 }
    ; Constructor mfs n as ss -> 
      do { let newBound = getBoundAtParameters as
	 ; (ss,_) <- liftStatements (combineEnv env newBound) ss
	 ; return (Constructor mfs n (liftParameters env as) ss)
	 }
    ; Method mfs t n as ts ss -> 
      do { let newBound = getBoundAtParameters as
	 ; (ss,_) <- liftStatements (combineEnv env newBound) ss
	 ; return (Method mfs (liftType env t) n (liftParameters env as) ts ss)
	 }
    ; Comment s -> return (Comment s)
    ; Interface mfs n is ms -> error "interfaces not supported"
    ; Class mfs n x is ms -> 
      do { let newBound = getBoundAtDecls ms
	 ; ms <- scopedName n
		    (liftDecls False (combineEnv env newBound) ms)
	 ; return (Class mfs n x is ms)
	 }
    }

liftDecls :: Bool -> Env -> [Decl] -> LifterM [Decl]
liftDecls top env = mapM (liftDecl top env)

getBoundAtDecls :: [Decl] -> Bound
getBoundAtDecls = foldr combine [] . map getBoundAtDecl

-- TODO
getBoundAtDecl :: Decl -> Bound
getBoundAtDecl (Field _ _ n _) = [n]
getBoundAtDecl _               = []

getBoundAtParameters :: [Parameter] -> Bound
getBoundAtParameters = foldr combine [] . map getBoundAtParameter

-- TODO
getBoundAtParameter :: Parameter -> Bound
getBoundAtParameter (Parameter _ _ n) = [n]

liftStatement :: Env -> Statement -> LifterM (Statement,Env)
liftStatement = \ env stmt ->
  case stmt of 
    { Skip -> return (stmt,env)
    ; Return e -> do { e <- liftExpr env e
		     ; return (Return e,env)
		     } 
    ; Block ss -> do { (ss,env) <- liftStatements env ss
		     ; return (Block ss,env)
		     }
    ; ExprStatement e -> do { e <- liftExpr env e
			    ; return (ExprStatement e,env)
			    }
   ; Declaration decl@(Field mfs t n e) ->
      do { e <- liftMaybeExpr env e
	 ; return ( Declaration (Field mfs t n e)
		  , env `combineEnv` getBoundAtDecl decl
		  )
	 }
    ; Declaration decl@(Class mfs n x is ms) ->
      do { innerName <- genInnerClassName n
	 ; frees <- liftClass env innerName ms x is
	 ; return ( Declaration (Comment ["lifted " ++  n])
		  , addTypeMapping n innerName frees env
		  )
	 }
    ; Declaration d -> error "general Decl not supported"
    ; IfThenElse ecs s -> ifthenelse env ecs s
    ; Switch e as d -> error "switch not supported"
    } 

ifthenelse :: Env 
	   -> [(Expr,Statement)] 
	   -> (Maybe Statement) 
	   -> LifterM (Statement,Env)
ifthenelse env pairs may_stmt =
  do { let (exprs,stmts) = unzip pairs
     ; exprs <- liftExprs env exprs
     ; (stmts,_) <- liftStatements env stmts
     ; may_stmt <- case may_stmt of
		      Just stmt -> do { (stmt,_) <- liftStatement env stmt
				      ; return (Just stmt)
				      }
		      Nothing -> return Nothing
     ; return (IfThenElse (zip exprs stmts) may_stmt,env)
     }

liftStatements :: Env -> [Statement] -> LifterM ([Statement],Env)
liftStatements env []     = return ([],env)
liftStatements env (s:ss) = 
	do { (s,env) <- liftStatement env s
	   ; (ss,env) <- liftStatements env ss
	   ; return (s:ss,env) 
	   }


liftExpr :: Env -> Expr -> LifterM Expr
liftExpr = \ env expr ->
 case expr of
   { Var n t -> do { access env n 
		   ; return (Var n t)
	           }
   ; Literal l _ -> return expr
   ; Cast t e -> do { e <- liftExpr env e
	            ; return (Cast (liftType env t) e) 
	            }
   ; Access e n -> do { e <- liftExpr env e 
			-- do not consider n as an access, because
			-- this is a indirection via a reference
		      ; return (Access e n) 
		      }
   ; Assign l r -> do { l <- liftExpr env l
		      ; r <- liftExpr env r
		      ; return (Assign l r)
		      } 
   ; InstanceOf e t -> do { e <- liftExpr env e
			  ; return (InstanceOf e (liftType env t))
			  }	    
   ; Call e n es -> do { e <- liftExpr env e
		       ; es <- mapM (liftExpr env) es
		       ; return (Call e n es) 
		       }
   ; Op e1 o e2 -> do { e1 <- liftExpr env e1
		      ;	e2 <- liftExpr env e2
		      ; return (Op e1 o e2)
		      }
   ; New n es ds -> new env n es ds
   }

liftParameter env (Parameter ms t n) = Parameter ms (liftType env t) n
liftParameters env = map (liftParameter env)

liftExprs :: Env -> [Expr] -> LifterM [Expr]
liftExprs = mapM . liftExpr

liftMaybeExpr :: Env -> (Maybe Expr) -> LifterM (Maybe Expr)
liftMaybeExpr env Nothing     = return Nothing
liftMaybeExpr env (Just stmt) = do { stmt <- liftExpr env stmt
				     ; return (Just stmt)
				     }


new :: Env -> Type -> [Expr] -> Maybe [Decl] -> LifterM Expr
new env@(Env _ pairs) typ args Nothing =
  do { args <- liftExprs env args
     ; return (listNew env typ args)
     }
new env typ [] (Just inner) =
  -- anon. inner class
  do { innerName <- genAnonInnerClassName 
     ; frees <- liftClass env innerName inner [] [unType typ]
     ; return (New (Type (innerName)) 
	      [ Var name (Type "<arg>") | name <- frees ] Nothing)
     }
  where unType (Type name) = name
	unType _             = error "incorrect type style"
	
new env typ _ (Just inner) = error "cant handle inner class with args"

liftClass :: Env -> Name -> [Decl] -> [Name] -> [Name] -> LifterM [ Name ]
liftClass env@(Env bound _) innerName inner xs is =
  do { let newBound = getBoundAtDecls inner
     ; (inner,frees) <- 
	   getFrees (liftDecls False (env `combineEnv` newBound) inner)
     ; let trueFrees = filter (\ xs -> xs /= "VM") (both frees bound)
     ; let freeDefs = [ Field [Final] objectType n Nothing | n <- trueFrees ]
     ; let cons = mkCons innerName [(name,objectType) | name <- trueFrees ]
     ; let innerClass = Class [] innerName xs is (freeDefs ++ [cons] ++ inner)
     ; rememberClass innerClass
     ; return trueFrees
     }

liftType :: Env -> Type -> Type
liftType (Env _ env) typ@(Type name) 
   = case lookup name env of
	Nothing     -> typ
	Just (nm,_) -> Type nm
liftType _           typ = typ

liftNew :: Env -> Type -> [Expr] -> Expr
liftNew (Env _ env) typ@(Type name) exprs
   = case lookup name env of
	Nothing                     -> New typ exprs Nothing
	Just (nm,args) | null exprs 
		-> New (Type nm) (map (\ v -> Var v (Type "<arg>")) args) Nothing
	_ -> error "pre-lifted constructor with arguments"
listNew _           typ exprs = New typ exprs Nothing

-}
\end{code}
