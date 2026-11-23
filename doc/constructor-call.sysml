package ConstructorCall {
    action def ConstructNativeTable {
        doc /* Closed POO call sites spell the same public Gerbil make-hash-table
               keywords literally. Gerbil owns default binding and construction. */
    }
    requirement def SameArgumentPacket {
        doc /* No dynamic arguments. test/hash procedure identities and every
               absent size/seed/lock/check/weak option match the convenience call. */
    }
    requirement def SameNativeBody {
        doc /* Compiler lowering may erase temporary keyword packing only.
               Keep native seed effects, adapters, callbacks, errors and freshness.
               Never call a private constructor or introduce a replacement API. */
    }
    requirement def NativeAcceptance {
        doc /* Check actual generated calls, default random state, backend and
               method identity; retain paired A/A and B/B controls. Then require
               complete .get, issued-read controls and linked entry acceptance. */
    }
}
