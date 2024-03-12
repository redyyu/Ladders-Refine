-- useless, the obj is the spot attached the sheetrope
-- it is no relate with ladder obj, which is downstair.
-- block from context menu is best options for now.

-- require "TimedActions/ISRemoveSheetRope"

-- function ISRemoveSheetRope:perform()
--     local obj = self.window
--     local index = obj:getObjectIndex()
--     print(obj:getTextureName())
--     print('--------ISRemoveSheetRope---------------------')
--     local args = { x=obj:getX(), y=obj:getY(), z=obj:getZ(), index=index }
--     sendClientCommand(self.character, 'object', 'removeSheetRope', args)

--     -- needed to remove from queue / start next.
--     ISBaseTimedAction.perform(self);
-- end
