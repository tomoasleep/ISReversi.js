
exports.get = (inputType) ->
  GETTING = 'getting'
  GOT = 'got'
  NO_GETTER = 'getter'
  NEXT_HANDLER = 'handler'

  if !@inExitHndler
    states = @states
    current = @state
    args = [].slice.call(arguments)
    getter = undefined
    action = undefined

    @currentActionArgs = args
    if states[current][inputType] || states[current]['*'] || @['*']
      getterName = if states[current][inputType] then inputType else '*'
      catchAll = getterName is '*'

      if states[current][getterName]
        getter = states[current][getterName]
        action = "#{current}.#{getterName}"
      else
        getter = @['*']
        action = '*'
      if !@_currentAction
        @_currentAction = action
      @emit.call @, GETTING,
        inputType: inputType
        args: args.slice(1)

      if typeof getter is 'function'
        getter = getter.apply @,
          if catchAll then args else args.slice(1)
      @emit.call @, GOT,
        inputType: inputType
        args: args.slice(1)
      @_priorAction = @_currentAction
      @_currentAction = ''
      @processQueue NEXT_HANDLER

    else
      @emit.call @, NO_GETTER,
        inputType: inputType
        args: args.slice(1)
    @currentActionArgs = undefined
    getter
