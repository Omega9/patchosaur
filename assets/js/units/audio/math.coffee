class PSMulAdd extends patchosaur.Unit
  # FIXME this doesn't work at all
  @names: ['muladd~']
  setup: (@objectModel, @args) ->
    # take num inlets from num args
    mul = @args[0] or 1
    add = @args[1] or 0
    # FIXME: error handling for non-number args?
    @objectModel.set numInlets: 3
    @objectModel.set numOutlets: 1
    a = patchosaur.audiolet
    @muladd = new MulAdd a, mul, add
    mulNode = new PassThroughNode a, 1, 1
    addNode = new PassThroughNode a, 1, 1
    mulNode.connect @muladd, 0, 1
    addNode.connect @muladd, 0, 2
    @inlets = [
        (->),
        ( (x) => @muladd.mul.setValue (+x)),
        ( (x) => @muladd.add.setValue (+x))
    ]
    @audioletInputNodes = [@muladd, mulNode, addNode]
    @audioletOutputNodes = [@muladd]

patchosaur.units.add PSMulAdd
