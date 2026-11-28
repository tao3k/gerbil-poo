;;-*- Gerbil -*-
;;; More types on top of POO and its MOP

(export (except-out #t %owned-list-slot-spec %ref-owned-list)
        Any Bool Object MonomorphicObject. MonomorphicObject ObjectObject
        Function. Function CaseFunction Fun
        Type Type. define-type element? validate TypeError TypeError? raise-type-error)

(import
  (only-in :std/assert assert!)
  :std/iter
  ./types/value-diagnostics
  ./types/validation
  ./types/variant-validation
  ./types/optional-validation
  (only-in :std/vector/u8vector big uint->u8vector u8vector->uint)
  (only-in :std/vector/vector vector-for-each/index)
  (only-in :std/hash/misc hash-key-value-map hash-ensure-ref)
  (only-in :std/list/list pop! map-in-order append-map)
  (only-in :std/list/alist acons plist->alist)
  (only-in :std/number/misc n-bits->n-u8)
  (only-in :std/encoding/hex hex-decode hex-encode)
  (only-in :std/func compose)
  (only-in ./support/base λ invalid ignore-errors hash)
  (only-in ./support/io u8vector<-<-marshal <-u8vector<-unmarshal write-u8vector*
           write-uint-u8vector read-uint-u8vector unmarshal-n-u8)
  (only-in ./support/json json-normalize string<-json json<-string)
  (only-in :gerbil/runtime/mop class-type? class-instance? class-type-final? class-type-slot-list
           class-type-id)
  (only-in :gerbil/runtime/interface interface-descriptor? interface-descriptor-type
           interface-descriptor-methods satisfies?)
  (only-in :gerbil/runtime/hash HashTable::interface)
  (only-in ./object .@ .ref object<-alist .slot? .call .o .putslot! seal-object! object::t object?)
  (only-in ./mop/prototype define-type Type Type. Class. Any Bool Object
           MonomorphicObject. MonomorphicObject ObjectObject Function. Function CaseFunction Fun
           TypeError TypeError? raise-type-error validate element? :sexp sexp<- json<- <-json)
  (only-in ./number UInt UIntN Real Integer)
  (only-in ./brace @method)
  (only-in ./io methods.bytes<-marshal methods.marshal<-bytes
           methods.marshal<-fixed-length-bytes methods.string<-json
           marshal unmarshal string<- <-string))

(include "types/sequences.ss")

(include "types/scalar-codecs.ss")

(include "types/combinations.ss")

(include "types/pairs.ss")

(include "types/optional.ss")

(include "types/associative.ss")

(include "types/sum.ss")

(include "types/gerbil-types.ss")
