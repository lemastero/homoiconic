{-# LANGUAGE UndecidableSuperClasses #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE DeriveGeneric #-}

module Algebra
    where

import qualified Prelude as P
import LocalPrelude
import Lattice
import Tests
import Topology1 hiding (Lawful (..), Semigroup (..), isLawful)

import Test.SmallCheck.Series hiding (NonNegative)
import Test.Tasty
import qualified Test.Tasty.SmallCheck as SC
import qualified Test.Tasty.QuickCheck as QC
import Test.QuickCheck hiding (Testable,NonNegative)

import Debug.Trace
import GHC.Generics

--------------------------------------------------------------------------------

class (cxt a, cxt b) => Sub (cxt :: Type -> Constraint) a b where
    embed :: Proxy cxt -> a -> b

instance cxt a => Sub cxt a a where
    embed _ = P.id

instance Sub Semigroup Integer Rational where
    embed _ = P.toRational

class Pointed a where point :: a
instance (Semigroup a, Semigroup b, Pointed b) => Sub Semigroup a (a,b) where
    embed _ a = (a,point)

instance (Semigroup a, Semigroup b, Pointed a) => Sub Semigroup b (a,b) where
    embed _ b = (point,b)

-- class a <: b where
--     embed :: a -> b
--
-- instance a <: a where
--     embed = P.id
--
-- instance Integer <: Rational where
--     embed =
--
-- instance (a,b) <: a where
--     embed = P.fst
--
-- instance (a,b) <: b where
--     embed = P.snd
--
-- instance a <: Maybe a where
--     embed = Just

--------------------------------------------------------------------------------

type (><) a b = Prod a b
class (cxt1 a, cxt2 a) => Prod cxt1 cxt2 a
instance (cxt1 a, cxt2 a) => Prod cxt1 cxt2 a

class HetAlgebra (cxt :: Type -> Constraint) where
    type SuperClasses (cxt :: Type -> Constraint) :: Type -> Constraint
    type HetDomain cxt a :: *
    type HetRange cxt a :: *
    op :: cxt a => Proxy (cxt a) -> HetDomain cxt a -> HetRange cxt a

instance HetAlgebra Semigroup where
    type SuperClasses Semigroup = Topology
    type HetDomain Semigroup a = (a,a)
    type HetRange  Semigroup a = a
    op _ (a1,a2) = a1+a2

instance HetAlgebra Monoid where
    type SuperClasses Monoid = Semigroup >< Topology
    type HetDomain Monoid a = ()
    type HetRange  Monoid a = a
    op _ _ = zero

instance HetAlgebra Topology where
    type SuperClasses Topology = Topology
    type HetDomain Topology a = (a,a)
    type HetRange Topology a = Logic a
    op _ (a1,a2) = a1==a2

--------------------

data Mor (cxt::Type->Constraint) a b where
    Mor :: (cxt a, cxt b)
        => (HetDomain cxt a -> HetDomain cxt b)
        -> (HetRange  cxt a -> HetRange  cxt b)
        -> Mor cxt a b

class Invariant (a::Type) (name::Symbol) where
    type InvariantDomain name a :: Type
    type InvariantRange  name a :: Type
    invariant :: a -> InvariantDomain name a -> Logic (InvariantRange name a)

instance (HetAlgebra cxt, Topology (HetRange cxt b)) => Invariant (Mor cxt a b) "morphism" where
    type InvariantDomain "morphism" (Mor cxt a b) = HetDomain cxt a
    type InvariantRange  "morphism" (Mor cxt a b) = HetRange  cxt b
    invariant (Mor f g) a = g (op (Proxy::Proxy (cxt a))    a)
                         ==    op (Proxy::Proxy (cxt b)) (f a)

--------------------

data Box cxt where
    Box :: forall cxt a. cxt -> Box cxt

data Box2 (cxt :: Type -> Constraint) a b where
    Box2 :: forall cxt x a b. cxt (x a b) => x a b -> Box2 cxt a b

type (a+>b) cxt = Box2 cxt a b

-- ($$) :: forall a b cxt. (a+>b) cxt -> a -> b
-- ($$) (HomC f) = case (getMor f::Mor cxt a b) of Mor f g -> undefined

data (a->>b) cxt where
    HomC :: forall cxt cat a b. (Hom cxt cat, cxt a, cxt b) => cat a b -> (a->>b) cxt

($$) :: forall a b cxt. (a->>b) cxt -> a -> b
($$) (HomC f) = case (getMor f::Mor cxt a b) of Mor f g -> undefined

class Hom (cxt :: Type -> Constraint) (cat :: Type -> Type -> Type) where
    getMor :: (cxt a, cxt b) => cat a b -> Mor cxt a b

--------------------------------------------------------------------------------

class Topology a => Semigroup a where
    infixr 6 +
    (+) :: a -> a -> a

instance Lawful Semigroup "associative" where
    type LawInput Semigroup "associative" a = (a,a,a)
    law _ _ _ (a1,a2,a3) = (a1+a2)+a3 == a1+(a2+a3)

--------------------

instance Semigroup Float where
    (+) = (P.+)

instance {-# OVERLAPS #-} Approximate Semigroup "associative" Float where
    maxError _ _ _ (a1,a2,a3) = Discrete $ NonNegative $ 2e-2

instance Semigroup Double where
    (+) = (P.+)

instance {-# OVERLAPS #-} Approximate Semigroup "associative" Double where
    maxError _ _ _ (a1,a2,a3) = Discrete $ NonNegative $ 2e-4

--------------------

instance (Semigroup a, Semigroup b) => Semigroup (a,b) where
    (a1,b1)+(a2,b2) = (a1+a2,b1+b2)

instance Semigroup () where
    ()+()=()

instance Semigroup Int where
    (+) = (P.+)

instance Semigroup Integer where
    (+) = (P.+)

instance Semigroup Rational where
    (+) = (P.+)

instance Topology a => Semigroup [a] where
    (+) = (P.++)

-- instance Semigroup a => Semigroup [a] where
--     (x:xr)+(y:yr) = x+y : xr+yr
--     []    +ys     = ys
--     xs    +[]     = xs

----------------------------------------

class Semigroup a => Monoid a where
    zero :: a

instance Lawful Monoid "idempotent_right" where
    type LawInput Monoid "idempotent_right" a = a
    law _ _ _ a = a+zero == a

instance Lawful Monoid "idempotent_left" where
    type LawInput Monoid "idempotent_left" a = a
    law _ _ _ a = zero+a == a

instance Monoid Int      where zero = 0
instance Monoid Integer  where zero = 0
instance Monoid Float    where zero = 0
instance Monoid Double   where zero = 0
instance Monoid Rational where zero = 0

----------------------------------------

class Monoid a => Group a where
    {-# MINIMAL negate | (-) #-}
    negate :: a -> a
    negate a = zero - a

    (-) :: a -> a -> a
    a1-a2 = a1 + negate a2

instance Lawful Group "negate" where
    type LawInput Group "negate" a = a
    law _ _ _ a = negate a == zero - a

instance Lawful Group "(-)" where
    type LawInput Group "(-)" a = (a,a)
    law _ _ _ (a1,a2) = a1-a2 == a1+negate a2

instance Lawful Group "cancellative" where
    type LawInput Group "cancellative" a = a
    law _ _ _ a = zero == a-a

instance Group Int          where negate = P.negate
instance Group Integer      where negate = P.negate
instance Group Float        where negate = P.negate
instance Group Double       where negate = P.negate
instance Group Rational     where negate = P.negate

----------------------------------------

class Group a => Ring a where
    one :: a
    (*) :: a -> a -> a

class Ring a => Field a where
    {-# MINIMAL reciprocal | (/) #-}
    reciprocal :: a -> a
    reciprocal a = one / a

    (/) :: a -> a -> a
    a1/a2 = a1 * reciprocal a2

-- type Hask = (->)
--
-- class Semigroup (cat :: * -> * -> *) a where
--     (+) :: cat a (cat a a)
--
-- instance Semigroup (->) Float where
--     (+) = (P.+)
--
-- instance Semigroup (->) b => Semigroup (->) (a -> b) where
--     (+) f1 f2 = \a -> f1 a + f2 a
--
-- instance Semigroup Top Float where
--     (+) = Top
--         { arrow = \a1 -> Top
--             { arrow = \a2 -> a1 P.+ a2
--             , inv = \_ nb -> nb
--             }
--         , inv = \a (_,nb) -> nb
--         }
--
-- instance (Semigroup (->) b, Semigroup Top b) => Semigroup (->) (Top a b) where
--     (+) (Top f1 inv1) (Top f2 inv2) = Top
--         { arrow = f1 + f2
--         , inv = undefined
--         }

