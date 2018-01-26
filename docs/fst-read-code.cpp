### FST details

Here is the fucking complicated class structure...
```c++
// A generic FST, templated on the arc definition, with common-demoninator
// methods (use StateIterator and ArcIterator to iterate over its states and
// arcs).
// just an interface, no member variable
template <class A>
class Fst {...};

// A generic FST plus state count.
template <class A>
class ExpandedFst : public Fst<A> {
  virtual StateId NumStates() const = 0;  // State count
}

// Abstract interface for an expanded FST which also supports mutation
// operations. To modify arcs, use MutableArcIterator.
template <class A>
class MutableFst : public ExpandedFst<A> {...}

// This is a helper class template useful for attaching an FST interface to
// its implementation, handling reference counting.
template <class Impl, class FST = Fst<typename Impl::Arc>>
class ImplToFst : public FST {...}

template <class Impl, class FST = ExpandedFst<typename Impl::Arc>>
class ImplToExpandedFst : public ImplToFst<Impl, FST> {...}

template <class Impl, class FST = MutableFst<typename Impl::Arc>>
class ImplToMutableFst : public ImplToExpandedFst<Impl, FST> {...}

// FST implementation base.
//
// This is the recommended FST implementation base class. It will handle
// reference counts, property bits, type information and symbols.
//
// Users are discouraged, but not prohibited, from subclassing this outside the
// FST library.
template <class Arc>
class FstImpl {
  mutable uint64 properties_;  // Property bits.
  string type_;  // Unique name of FST class.
  std::unique_ptr<SymbolTable> isymbols_;
  std::unique_ptr<SymbolTable> osymbols_;
};

// States are implemented by STL vectors, templated on the
// State definition. This does not manage the Fst properties.
template <class State>
class VectorFstBaseImpl : public FstImpl<typename S::Arc> {
  using StateId = typename State::Arc::StateId;
  std::vector<State *> states_;                 // States represenation.
  StateId start_;                               // Initial state.
}

// This is a VectorFstBaseImpl container that holds VectorStates and manages FST
// properties.
template <class S>
class VectorFstImpl : public VectorFstBaseImpl<S> {...}

template <class A, class S /* = VectorState<A> */>
VectorFst : public ImplToMutableFst<internal::VectorFstImpl<S>> {...}
```

```c++
// Arcs (of type A) implemented by an STL vector per state. M specifies Arc
// allocator (default declared in fst-decl.h).
template <class A, class M /* = std::allocator<A> */>
class VectorState {
  using Arc = A;
  using Weight = typename Arc::Weight;

  Weight final_;                       // Final weight.
  size_t niepsilons_;                  // # of input epsilons
  size_t noepsilons_;                  // # of output epsilons
  std::vector<A, ArcAllocator> arcs_;  // Arc container.
};
```

```c++
// We are using VectorFst<StdArc>

using StdArc = ArcTpl<TropicalWeight>;

template <class W>
struct ArcTpl {
 public:
  using Weight = W;
  using Label = int;
  using StateId = int;

  Label ilabel;
  Label olabel;
  Weight weight;
  StateId nextstate;
};

using TropicalWeight = TropicalWeightTpl<float>;

// Tropical semiring: (min, +, inf, 0).
template <class T>
class TropicalWeightTpl : public FloatWeightTpl<T> {...}

// Weight class to be templated on floating-points types.
template <class T = float>
class FloatWeightTpl {
  T value_;
};

static const TropicalWeightTpl<T> &Zero() {
  static const TropicalWeightTpl zero(Limits::PosInfinity());
  return zero;
}

// worth noting
static const TropicalWeightTpl<T> &One() {
  static const TropicalWeightTpl one(0.0F);
  return one;
}

static const TropicalWeightTpl<T> &NoWeight() {
  static const TropicalWeightTpl no_weight(Limits::NumberBad());
  return no_weight;
}
```

Fst properties:
  - kExpanded
  - kMutable
  - kError
  - kAcceptor // ilabel == olabel for each arc
  - kNotAcceptor // ilabel != olabel for some arc
  - kIDeterministic // ilabels unique leaving each state
  - kNonIDeterministic // ilabels not unique leaving some state
  - kODeterministic // olabels unique leaving each state
  - kNonODeterministic // olabels not unique leaving some state
  - kEpsilons // FST has input/output epsilons
  - kNoEpsilons // FST has no input/output epsilons
  - kIEpsilons
  - kNoIEpsilons
  - kOEpsilons
  - kNoOEpsilons
  - kILabelSorted // ilabels sorted wrt < for each state
  - kNotILabelSorted
  - kOLabelSorted
  - kNotOLabelSorted
  - kWeighted // Non-trivial arc or final weights.
  - kUnweighted
  - kCyclic
  - kAcyclic
  - kInitialCyclic // FST has cycles containing the initial state
  - kInitialAcyclic
  - kTopSorted // FST is topologically sorted
  - kNotTopSorted
  - kAccessible // All states reachable from the initial state
  - kNotAccessible
  - kCoAccessible // All states can reach a final state
  - kNotCoAccessible
  - kString
    - If NumStates() > 0, then state 0 is initial, state NumStates() - 1 is final, there is a transition from each non-final state i to state i + 1, and there are no other transitions.
  - kNotString // Not a string FST.
  - kWeightedCycles // FST has least one weighted cycle.
  - kUnweightedCycles // Only unweighted cycles.

Context fst:
```c++
// Actual FST for ContextFst.  Most of the work gets done in ContextFstImpl.
//
// A ContextFst is a transducer from symbols representing phones-in-context,
// to phones.  It is an on-demand FST.  However, it does not create itself in the usual
// way by expanding states by enumerating all their arcs.  This is possible to enable
// iterating over arcs, but it is not recommended.  Instead, we define a special
// Matcher class that knows how to request the specific arc corresponding to a particular
// output label.
//
// This class requires a list of all the phones and disambiguation
// symbols, plus the subsequential symbol.  This is required to be able to
// enumerate all output symbols (if we want to access it in an inefficient way), and
// also to distinguish between phones and disambiguation symbols.
template <class Arc,
          class LabelT = int32> // make the vector<LabelT> things actually vector<int32> for
                                // easier compatibility with Kaldi code.
class ContextFst : public ImplToFst<internal::ContextFstImpl<Arc, LabelT>> {
};

// ContextFstImpl inherits from CacheImpl, which handles caching of states.
template <class Arc,
          class LabelT = int32>
class ContextFstImpl : public CacheImpl<Arc> {
};

// A CacheBaseImpl with the default cache state type.
template <class Arc>
class CacheImpl : public CacheBaseImpl<CacheState<Arc>> {
};

// This class is used to cache FST elements stored in states of type State
// (see CacheState) with the flags used to indicate what has been cached. Use
// HasStart(), HasFinal(), and HasArcs() to determine if cached and SetStart(),
// SetFinal(), AddArc(), (or PushArc() and SetArcs()) to cache. Note that you
// must set the final weight even if the state is non-final to mark it as
// cached. The state storage method and any garbage collection policy are
// determined by the cache store. If the store is passed in with the options,
// CacheBaseImpl takes ownership.
template <class State,
          class CacheStore = DefaultCacheStore<typename State::Arc>>
class CacheBaseImpl : public FstImpl<typename State::Arc> {
};

// Cache state, with arcs stored in a per-state std::vector.
template <class A, class M = PoolAllocator<A>>
class CacheState {}

```
