module PetriGraph

import Data.Vect
import Basic.Category
import Basic.Functor
import Product.ProductCategory
import Permutations.Permutations
import Cartographer.Hypergraph
import Cartographer.HypergraphStrictMonoidalCategory
import MonoidalCategory.StrictMonoidalCategory


%default total
{-
StringDiag := {
  tensor := {
    tensor := {
      f
      g
    }
    sequence := {
      h
      identity A
      }
    }
  }
}

data Tree o m = Tensor Tree Tree | Sequence Tree Tree | Id o | Mor m
-}
-- PetriSpec
-- Vertex: Nat, Edges : List ((List Nat), (List Nat))
{-
PetriVertex : TDefR 0
PetriVertex = TProd [TList Nat, TList (TList Nat, TList Nat)]

PetriState : TDefR 0
PetriState = TList `ap` TNat

PetriPath : TDefR 2
PetriPath = TMu [ ("Tensor", TProd [TVar 0, TVar 0])
                , ("Sequence", TProd [TVar 0, TVar 0])
                , ("Id", TVar 1)
                , ("Mor", TVar 2)
                ]

-}

record PetriSpec (k : Nat) where
  constructor MkPetriSpec
  Places : Nat
  Edges : Vect k (List (Fin Places), List (Fin Places))

PetriState : Type
PetriState = List Nat

data Tree o m = Tensor (Tree o m) (Tree o m)
              | Sequence (Tree o m) (Tree o m)
              | Sym o o
              | Id o
              | Mor m

Domain : (morphisms : Vect k (List a, List a)) -> Tree a (Fin k) -> List a
Domain m (Tensor l r) = (Domain m l) ++ (Domain m r)
Domain m (Sequence l r) = Domain m l
Domain m (Id o) = pure o
Domain m (Sym l r) = [l, r]
Domain m (Mor i) = fst $ index i m


Codomain : (morphisms : Vect k (List a, List a)) -> Tree a (Fin k) -> List a
Codomain m (Tensor l r) = Codomain m l ++ Codomain m r
Codomain m (Sequence l r) = Codomain m r
Codomain m (Id o) = pure o
Codomain m (Sym l r) = [r, l]
Codomain m (Mor i) = snd $ index i m


PetriPath : Nat -> Nat -> Type
PetriPath places k = Tree (Fin places) (Fin k)

everything : (spec : PetriSpec k) -> (path : PetriPath (Places spec) k)
          -> Maybe (mor (cat (hypergraphSMC (Fin k)
                                            (\m => fst $ index m (Edges spec))
                                            (\m => snd $ index m (Edges spec))))
                        (Domain (Edges spec) path)
                        (Codomain (Edges spec) path))
everything s (Tensor lt rt) = [| everything s lt `add` everything s rt |]
everything s (Sequence lt rt) {k} = do
  lt' <- everything s lt
  rt' <- everything s rt
  case decEq (Domain (Edges s) rt) (Codomain (Edges s) lt) of
       Yes p =>  let rt'' = replace
                              {P = (\newDom => Hypergraph (Fin k)
                                                 (\m => fst $ index m (Edges s))
                                                 (\m => snd $ index m (Edges s))
                                                 newDom
                                                 (Codomain (Edges s) rt))
                              }
                              p rt' in pure (compose lt' rt'')
       No _ => Nothing
everything _ (Sym a b) = Just (permutation (swap [a] [b]))
everything _ (Id o) = Just (Hypergraph.identity [o])
everything _ (Mor m) = Just (Hypergraph.singleton m)