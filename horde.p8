pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
--todo : maintenir appuyé permet de faire une ligne
--bug: passer en tool 3 puis sortir écran rend certaines cases inategnables avec les tools snappés
--bug: la console merde à afficher plus de deux lignes s'il y a un trou entre deux lignes
--ascii: http://www.patorjk.com/software/taag/#p=display&h=0&v=0&f=doh&t=grid (font doh)
--todo: refaire une passe sur le nommage 

--grid coordinates
grid = {}
grid_size_x = 14
grid_size_y = 4
grid_shift_x = grid_size_x / 2
--array containing all the built blocks sorted from above to below
built_blocks = {}
--mouse
pressed = false
target = {}
mouse_hand = 32
mouse_pressed = 48
mouse_finger = {}
shift_target_y = -5 --light shift to make the snap more natural
--blocks data
blocks_atlas = {6, 4}
blocks_tags = {{"sand"}, {"water"}}
--tools
tools_atlas = {0, 16} --1 is to add, 2 is to delete, 0 is nothing
selected_tool = 0
free_delete_button = 12
selected_delete_button = 14 
overed_tool = 0 --id of the overed tool
delete_button = {} --coordinates of the delete button
--palettte
free_palette_atlas = {44, 42}
selected_palette_atlas = {45, 43}
selected_palette = 1
overed_palette = 0 --id of the overed palette button
grass_button = {}
water_button = {}
stone_button = {}
--ui
ui_line = 109 --y coordinates of the ui
blink_time = 0.5 --period for something to blink
--wild
small_grass_rule = 
{id_self = 1, --grass id
 id_target = 1, --id of the block where grass grows
 id_neighbours = 2, --id of neighbour blocks
 rule_tags = {"weak", "grass", "direct", "green"}, --tags of this asset
 required_tags = {"water"}, --tags of its neighbours
 amount_neighbours = 1, --amount of neighbours requiered for grass
 time_to_grow = 1.0,--time in seconds to transform
 priority = 2, --doesn't apply if the current rule has a higher priority
 atlas = 80}--sprite index 

big_grass_rule = 
{id_self = 2,
 id_target = 1,
 id_neighbours = 2,
 rule_tags = {"strong", "grass", "direct", "green"},
 required_tags = {"water"},
 amount_neighbours = 2,
 time_to_grow = 1.0,
 priority = 3,
 atlas = 64}

forest_rule = 
{id_self = 3,
 id_target = 1,
 id_neighbours = 1,
 rule_tags = {"forest", "direct", "green"},
 required_tags = {"strong", "grass"},
 amount_neighbours = 2,
 time_to_grow = 1.0,
 priority = 4,
 atlas = 96}

indirect_grass_rule =
{id_self = 4,
 id_target = 1,
 id_neighbours = 1,
 rule_tags = {"weak", "grass", "green"},
 required_tags = {"green", "direct"},
 amount_neighbours = 1,
 time_to_grow = 2.0,
 priority = 1,
 atlas = 80}

wild_rules = {forest_rule, big_grass_rule, small_grass_rule, indirect_grass_rule}
--debug
debug = false --if true, we print the console
console_rect = {x1 = 0, y1 = 0, x2 = 128, y2 = 9}
console = {"debug true"} 

--            dddddddd                                                           
--            d::::::d                           tttt                            
--            d::::::d                        ttt:::t                            
--            d::::::d                        t:::::t                            
--            d:::::d                         t:::::t                            
--    ddddddddd:::::d   aaaaaaaaaaaaa   ttttttt:::::ttttttt      aaaaaaaaaaaaa   
--  dd::::::::::::::d   a::::::::::::a  t:::::::::::::::::t      a::::::::::::a  
-- d::::::::::::::::d   aaaaaaaaa:::::a t:::::::::::::::::t      aaaaaaaaa:::::a 
--d:::::::ddddd:::::d            a::::a tttttt:::::::tttttt               a::::a 
--d::::::d    d:::::d     aaaaaaa:::::a       t:::::t              aaaaaaa:::::a 
--d:::::d     d:::::d   aa::::::::::::a       t:::::t            aa::::::::::::a 
--d:::::d     d:::::d  a::::aaaa::::::a       t:::::t           a::::aaaa::::::a 
--d:::::d     d:::::d a::::a    a:::::a       t:::::t    tttttta::::a    a:::::a 
--d::::::ddddd::::::dda::::a    a:::::a       t::::::tttt:::::ta::::a    a:::::a 
-- d:::::::::::::::::da:::::aaaa::::::a       tt::::::::::::::ta:::::aaaa::::::a 
--  d:::::::::ddd::::d a::::::::::aa:::a        tt:::::::::::tt a::::::::::aa:::a
--   ddddddddd   ddddd  aaaaaaaaaa  aaaa          ttttttttttt    aaaaaaaaaa  aaaa

--create a vector
function _new_vector(x, y)
 vector = {
  x = x,
  y = y
 }
 return vector
end
-------------------------------------------------------------------------------
--create a block
function _new_block(x, y, id)
 return {
  x = x,
  y = y,
  id = id, --type of block
  current_subtype = 0,
  next_subtype = 0,
  transformation_time = 0.0,
  subtype_priority = 0,
  tags = blocks_tags[id]
 }
end


--  iiii                      iiii           tttt          
-- i::::i                    i::::i       ttt:::t          
--  iiii                      iiii        t:::::t          
--                                        t:::::t          
--iiiiiii nnnn  nnnnnnnn    iiiiiii ttttttt:::::ttttttt    
--i:::::i n:::nn::::::::nn  i:::::i t:::::::::::::::::t    
-- i::::i n::::::::::::::nn  i::::i t:::::::::::::::::t    
-- i::::i nn:::::::::::::::n i::::i tttttt:::::::tttttt    
-- i::::i   n:::::nnnn:::::n i::::i       t:::::t          
-- i::::i   n::::n    n::::n i::::i       t:::::t          
-- i::::i   n::::n    n::::n i::::i       t:::::t          
-- i::::i   n::::n    n::::n i::::i       t:::::t    tttttt
--i::::::i  n::::n    n::::ni::::::i      t::::::tttt:::::t
--i::::::i  n::::n    n::::ni::::::i      tt::::::::::::::t
--i::::::i  n::::n    n::::ni::::::i        tt:::::::::::tt
--iiiiiiii  nnnnnn    nnnnnniiiiiiii          ttttttttttt  
                                                         
function _init()
 --building the grid
 shift = 0
 for y = 0, 127, grid_size_y do
  for x = 0, 127, grid_size_x do
   add(grid, _new_vector(x + shift * grid_shift_x, y))
  end
  shift = (shift + 1) % 2
 end
 --initiate the ui
 mouse_finger = _new_vector(6, 0)
 delete_button = _new_vector(1, 112)
 grass_button = _new_vector(16, 112)
 water_button = _new_vector(24, 112)
 stone_button = _new_vector(32, 112)
 --enable the use of the mouse
 poke(0x5f2d, 1)
 last_time = time()
end

                                                                                                                   
--                                                  dddddddd                                                             
--                                                  d::::::d                           tttt                              
--                                                  d::::::d                        ttt:::t                              
--                                                  d::::::d                        t:::::t                              
--                                                  d:::::d                         t:::::t                              
--uuuuuu    uuuuuu  ppppp   ppppppppp       ddddddddd:::::d   aaaaaaaaaaaaa   ttttttt:::::ttttttt        eeeeeeeeeeee    
--u::::u    u::::u  p::::ppp:::::::::p    dd::::::::::::::d   a::::::::::::a  t:::::::::::::::::t      ee::::::::::::ee  
--u::::u    u::::u  p:::::::::::::::::p  d::::::::::::::::d   aaaaaaaaa:::::a t:::::::::::::::::t     e::::::eeeee:::::ee
--u::::u    u::::u  pp::::::ppppp::::::pd:::::::ddddd:::::d            a::::a tttttt:::::::tttttt    e::::::e     e:::::e
--u::::u    u::::u   p:::::p     p:::::pd::::::d    d:::::d     aaaaaaa:::::a       t:::::t          e:::::::eeeee::::::e
--u::::u    u::::u   p:::::p     p:::::pd:::::d     d:::::d   aa::::::::::::a       t:::::t          e:::::::::::::::::e 
--u::::u    u::::u   p:::::p     p:::::pd:::::d     d:::::d  a::::aaaa::::::a       t:::::t          e::::::eeeeeeeeeee  
--u:::::uuuu:::::u   p:::::p    p::::::pd:::::d     d:::::d a::::a    a:::::a       t:::::t    tttttte:::::::e           
--u:::::::::::::::uu p:::::ppppp:::::::pd::::::ddddd::::::dda::::a    a:::::a       t::::::tttt:::::te::::::::e          
-- u:::::::::::::::u p::::::::::::::::p  d:::::::::::::::::da:::::aaaa::::::a       tt::::::::::::::t e::::::::eeeeeeee  
--  uu::::::::uu:::u p::::::::::::::pp    d:::::::::ddd::::d a::::::::::aa:::a        tt:::::::::::tt  ee:::::::::::::e  
--    uuuuuuuu  uuuu p::::::pppppppp       ddddddddd   ddddd  aaaaaaaaaa  aaaa          ttttttttttt      eeeeeeeeeeeeee  
--                   p:::::p                                                                                             
--                   p:::::p                                                                                             
--                  p:::::::p                                                                                            
--                  p:::::::p                                                                                            
--                  p:::::::p                                                                                            
--                  ppppppppp           

function _update()
 local delta_time = time() - last_time
 -- updates the blocks
 _transform_blocks(delta_time)
 --update the mouse position
 if selected_tool != 0 then 
  target = _snap_to_grid(stat(32), stat(33) + shift_target_y)
 else --free mouse when no tool selected:
  target.x = stat(32)
  target.y = stat(33)
 end
 
 --right click to unselect a tool
 if stat(34) == 2 then
  if not pressed then
   selected_tool = 0
  end
 --if we left click, we use the selected tool at the mouse position
 elseif stat(34) == 1 then
  pressed = true
  --cannot build a block below the ui line (todo: refactor that)
  if stat(33) < ui_line then
   if selected_tool == 1 then --build a block
    built_blocks = _add_sort_block(target.x, target.y, selected_palette, built_blocks)
   else --destroy a block
    built_blocks = _remove_block(target.x, target.y, built_blocks)
   end
  end
 else
  pressed = false
 end
 --ui buttons
 _tool_button(delete_button, 2)
 _palette_button(_new_vector(grass_button.x, grass_button.y + 3), 1)
 _palette_button(_new_vector(water_button.x, water_button.y + 3), 2)
 _palette_button(_new_vector(stone_button.x, stone_button.y + 3), 3)
 --wild
 foreach(wild_rules, _apply_wild_rule)
 last_time = time()
end

--            dddddddd                                                                               
--            d::::::d                                                                               
--            d::::::d                                                                               
--            d::::::d                                                                               
--            d:::::d                                                                                
--    ddddddddd:::::d rrrrr   rrrrrrrrr     aaaaaaaaaaaaa   wwwwwww           wwwww           wwwwwww
--  dd::::::::::::::d r::::rrr:::::::::r    a::::::::::::a   w:::::w         w:::::w         w:::::w 
-- d::::::::::::::::d r:::::::::::::::::r   aaaaaaaaa:::::a   w:::::w       w:::::::w       w:::::w  
--d:::::::ddddd:::::d rr::::::rrrrr::::::r           a::::a    w:::::w     w:::::::::w     w:::::w   
--d::::::d    d:::::d  r:::::r     r:::::r    aaaaaaa:::::a     w:::::w   w:::::w:::::w   w:::::w    
--d:::::d     d:::::d  r:::::r     rrrrrrr  aa::::::::::::a      w:::::w w:::::w w:::::w w:::::w     
--d:::::d     d:::::d  r:::::r             a::::aaaa::::::a       w:::::w:::::w   w:::::w:::::w      
--d:::::d     d:::::d  r:::::r            a::::a    a:::::a        w:::::::::w     w:::::::::w       
--d::::::ddddd::::::dd r:::::r            a::::a    a:::::a         w:::::::w       w:::::::w        
-- d:::::::::::::::::d r:::::r            a:::::aaaa::::::a          w:::::w         w:::::w         
--  d:::::::::ddd::::d r:::::r             a::::::::::aa:::a          w:::w           w:::w          
--   ddddddddd   ddddd rrrrrrr              aaaaaaaaaa  aaaa           www             www           

function _draw()
 --check if the mouse is not on the ui
 if stat(33) < ui_line then
  --prepare a grid containg the blocks and the target in case the building tool is selected
  if selected_tool == 1 then
   drawn_grid = _add_sort_block(target.x, target.y, selected_palette, built_blocks)
  elseif selected_tool == 2 then
   if _blinker(blink_time) then
    drawn_grid = _remove_block(target.x, target.y, built_blocks)
   else
    drawn_grid = built_blocks
   end
  else
   drawn_grid = built_blocks
  end
 else
  drawn_grid = built_blocks
 end
 --draws a black rect as a background
 rectfill(0,0,127,128,7)
 --draws all the built blocks
 for i = 1, #drawn_grid, 1 do
  spr(blocks_atlas[drawn_grid[i].id], drawn_grid[i].x, drawn_grid[i].y, 2, 2)
  --draws the wild
  if drawn_grid[i].current_subtype != 0 then
   tested_rule = 1
   subtype_found = false
   while subtype_found == false do --we test all the rules to find the proper asset
    if drawn_grid[i].current_subtype == wild_rules[tested_rule].id_self then
     spr(wild_rules[tested_rule].atlas, drawn_grid[i].x, drawn_grid[i].y, 2, 1)
     subtype_found = true
    end
    tested_rule += 1
   end
  end
 end
 --ui
 _draw_tool_button(2, selected_tool, overed_tool, delete_button.x, delete_button.y)
 _draw_palette_button(1, selected_palette, overed_palette, grass_button.x, grass_button.y, 1, 2, selected_palette_atlas, free_palette_atlas)
 _draw_palette_button(2, selected_palette, overed_palette, water_button.x, water_button.y, 1, 2, selected_palette_atlas, free_palette_atlas)
 spr(46, water_button.x + 8, water_button.y, 1, 2) --closes the ui bar
 --draws the mouse pointer according to the selected tool
 if stat(33) < ui_line and selected_tool != 0 then
  spr(tools_atlas[selected_tool], target.x, target.y, 2, 1)
 end
 --draws the mouse hand differently depending on if pressed
 if pressed then
  spr(mouse_pressed, stat(32), stat(33), 2, 1)
 else
  spr(mouse_hand, stat(32), stat(33), 2, 1)
 end
 --debug console
 if debug then
  for i = 1, #console do
  rectfill(console_rect.x1, console_rect.y1 + console_rect.y2 * (i - 1), console_rect.x2, console_rect.y2 * i, 1)
  print(console[i], console_rect.x1 + 1, console_rect.y1 + (i - 1) * 10 + 1, 5)
  end
 end
end


--uuuuuuuu     uuuuuuuuiiiiiiiiii
--u::::::u     u::::::ui::::::::i
--u::::::u     u::::::ui::::::::i
--uu:::::u     u:::::uuii::::::ii
-- u:::::u     u:::::u   i::::i  
-- u:::::d     d:::::u   i::::i  
-- u:::::d     d:::::u   i::::i  
-- u:::::d     d:::::u   i::::i  
-- u:::::d     d:::::u   i::::i  
-- u:::::d     d:::::u   i::::i  
-- u:::::d     d:::::u   i::::i  
-- u::::::u   u::::::u   i::::i  
-- u:::::::uuu:::::::u ii::::::ii
--  uu:::::::::::::uu  i::::::::i
--    uu:::::::::uu    i::::::::i
--      uuuuuuuuu      iiiiiiiiii

--draw a tool button
function _draw_tool_button(tool_id, selected_id, overed_id, x, y)
 if tool_id == selected_id then
  spr(selected_delete_button, x, y, 2, 2)
 elseif tool_id == overed_id then
  spr(selected_delete_button, x, y, 2, 2)
 else
  spr(free_delete_button, x, y, 2, 2)
 end
end
-------------------------------------------------------------------------------
--draw a palette button
function _draw_palette_button(palette_id, selected_id, overed_id, x, y)
 if palette_id == selected_id and selected_tool == 1 then
  spr(selected_palette_atlas[palette_id], x, y, 1, 2)
 elseif palette_id == overed_id then
  spr(selected_palette_atlas[palette_id], x, y, 1, 2)
 else
  spr(free_palette_atlas[palette_id], x, y, 1, 2)
 end
end
-------------------------------------------------------------------------------
--checks if a point is in a square
function _is_colliding(x, y, position, size)
 if x >= position.x and x < position.x + size.x and 
    y >= position.y and y < position.y + size.y then
  return true
 else
  return false
 end
end
-------------------------------------------------------------------------------
--handle over and click on a tool button
function _tool_button(button_position, tool_id)
 if _is_colliding(stat(32)+mouse_finger.x, stat(33)+mouse_finger.y, button_position, _new_vector(16,16)) then
  overed_tool = tool_id
  if stat(34) == 1 then
   selected_tool = tool_id
  end
 elseif overed_tool == tool_id then
  overed_tool = 0
 end
end
-------------------------------------------------------------------------------
--handle over and click on a palette button
function _palette_button(button_position, palette_id)
 if _is_colliding(stat(32)+mouse_finger.x, stat(33)+mouse_finger.y, button_position, _new_vector(8,16)) then
  overed_palette = palette_id
  if stat(34) == 1 then
   selected_palette = palette_id
   selected_tool = 1
  end
 elseif overed_palette == palette_id then
  overed_palette = 0
 end
end
-------------------------------------------------------------------------------
--returns true or false depending on the time
function _blinker(period)
 if time() % period > period / 2 then
  return true
 else
  return false
 end
end


--                                                            dddddddd
--                                          iiii              d::::::d
--                                         i::::i             d::::::d
--                                          iiii              d::::::d
--                                                            d:::::d 
--   ggggggggg   gggggrrrrr   rrrrrrrrr   iiiiiii     ddddddddd:::::d 
--  g:::::::::ggg::::gr::::rrr:::::::::r  i:::::i   dd::::::::::::::d 
-- g:::::::::::::::::gr:::::::::::::::::r  i::::i  d::::::::::::::::d 
--g::::::ggggg::::::ggrr::::::rrrrr::::::r i::::i d:::::::ddddd:::::d 
--g:::::g     g:::::g  r:::::r     r:::::r i::::i d::::::d    d:::::d 
--g:::::g     g:::::g  r:::::r     rrrrrrr i::::i d:::::d     d:::::d 
--g:::::g     g:::::g  r:::::r             i::::i d:::::d     d:::::d 
--g::::::g    g:::::g  r:::::r             i::::i d:::::d     d:::::d 
--g:::::::ggggg:::::g  r:::::r            i::::::id::::::ddddd::::::dd
-- g::::::::::::::::g  r:::::r            i::::::i d:::::::::::::::::d
--  gg::::::::::::::g  r:::::r            i::::::i  d:::::::::ddd::::d
--    gggggggg::::::g  rrrrrrr            iiiiiiii   ddddddddd   ddddd
--           g:::::g                                                 
--gggggg      g:::::g                                                 
--g:::::gg   gg:::::g                                                 
-- g::::::ggg:::::::g                                                 
--  gg:::::::::::::g                                                  
--    ggg::::::ggg                                                    
--       gggggg                                                       

--return a vector of a grid coord close to the input vector
function _snap_to_grid(x, y)
 local distance = -1
 local id = 1
 --check the closest point of the grid
 for i = 1, #grid do
  --compute the squared distance
  dx = (x - grid[i].x) * (x - grid[i].x)
  dy = (y - grid[i].y) * (y - grid[i].y)
  --compare the result with the shortest vector so far
  if dx + dy < distance or i == 1 then 
   distance = dx + dy
   id = i
  end
 end
 return grid[id]
end
-------------------------------------------------------------------------------
--add a block to a grid, and sort them from above to bellow
function _add_sort_block(x, y, id, grid_to_sort)
 local buffer_blocks = {} --this table is the new grid_to_sort table
 local continue = true --when we found the right id, we stop the loop
 grid_to_sort = _remove_block(x, y, grid_to_sort) --we remove existing blocks at this position /!\ very buggy
 if #grid_to_sort == 0 then
  add(buffer_blocks, _new_block(x, y, id))
 else
  --we search for a block lower than ours
  for i = 1, #grid_to_sort do
   if y < grid_to_sort[i].y and continue then
    add(buffer_blocks, _new_block(x, y, id))
    continue = false
   end
   add(buffer_blocks, grid_to_sort[i])
  end
  --in case we didn't find a valid spot
  if continue then
   add(buffer_blocks, _new_block(x, y, id))
  end
 end
 return buffer_blocks
end
-------------------------------------------------------------------------------
--returns a grid without the block which was at the targeted position
function _remove_block(x, y, grid_to_sort)
 local buffer_blocks = {} --this table is the new grid_to_sort table
 --we add to buffer_blocks all the blocks that don't match the position
 for i = 1, #grid_to_sort do
  if grid_to_sort[i].x != x or grid_to_sort[i].y != y then
   add(buffer_blocks, grid_to_sort[i])
  end
 end
 return buffer_blocks
end

--   ggggggggg   ggggg aaaaaaaaaaaaa      mmmmmmm    mmmmmmm       eeeeeeeeeeee    
--  g:::::::::ggg::::g a::::::::::::a   mm:::::::m  m:::::::mm   ee::::::::::::ee  
-- g:::::::::::::::::g aaaaaaaaa:::::a m::::::::::mm::::::::::m e::::::eeeee:::::ee
--g::::::ggggg::::::gg          a::::a m::::::::::::::::::::::me::::::e     e:::::e
--g:::::g     g:::::g    aaaaaaa:::::a m:::::mmm::::::mmm:::::me:::::::eeeee::::::e
--g:::::g     g:::::g  aa::::::::::::a m::::m   m::::m   m::::me:::::::::::::::::e 
--g:::::g     g:::::g a::::aaaa::::::a m::::m   m::::m   m::::me::::::eeeeeeeeeee  
--g::::::g    g:::::ga::::a    a:::::a m::::m   m::::m   m::::me:::::::e           
--g:::::::ggggg:::::ga::::a    a:::::a m::::m   m::::m   m::::me::::::::e          
-- g::::::::::::::::ga:::::aaaa::::::a m::::m   m::::m   m::::m e::::::::eeeeeeee  
--  gg::::::::::::::g a::::::::::aa:::am::::m   m::::m   m::::m  ee:::::::::::::e  
--    gggggggg::::::g  aaaaaaaaaa  aaaammmmmm   mmmmmm   mmmmmm    eeeeeeeeeeeeee  
--            g:::::g                                                              
--gggggg      g:::::g                                                              
--g:::::gg   gg:::::g                                                              
-- g::::::ggg:::::::g                                                              
--  gg:::::::::::::g                                                               
--    ggg::::::ggg                                                                 
--       gggggg                                                                                    

--test if an amount of neighbours fits with an id and tags condition
function _pick_neighbours(x, y, amount, id, rule_tags)
 local found = false
 local total = 0 --amount of neighbours found
 for i = 1, #built_blocks do
  if built_blocks[i].id == id and _test_neighbour_tags(rule_tags, built_blocks[i].tags) then
   if (built_blocks[i].x == x + grid_size_x / 2 and built_blocks[i].y == y + grid_size_y) then --right neighbour
    found = true
   end
   if (built_blocks[i].x == x - grid_size_x / 2 and built_blocks[i].y == y + grid_size_y) then --left neighbour
    found = true
   end
   if (built_blocks[i].x == x + (grid_size_x / 2) and built_blocks[i].y == y - grid_size_y) then --above neighbour
    found = true
   end
   if (built_blocks[i].x == x - (grid_size_x / 2) and built_blocks[i].y == y - grid_size_y) then--below neighbour
    found = true
   end
   if found then
    found = false
    total += 1
   end
  end
 end
 return total >= amount
end
-------------------------------------------------------------------------------
--tests that a neighbour contains all the tags from a block
function _test_neighbour_tags(block_tags, neighbour_tags)
 match = true --we return this value at the end
 for i = 1, #block_tags do --we try to find the block's tags one per one
  tag_found = false 
  for y = 1, #neighbour_tags do
   if block_tags[i] == neighbour_tags[y] then
    tag_found = true
   else
   --nothing
   end
  end
  if tag_found == false then
   match = false --if the neighbour doesn't contain at least one tag from the block, it's a fail
  end
 end
 return match
end
-------------------------------------------------------------------------------
--transform all blocks to their next subtype
function _transform_blocks(delta_time)
 for i = 1, #built_blocks do
  if built_blocks[i].current_subtype != built_blocks[i].next_subtype then
   if built_blocks[i].transformation_time <= 0.0 then
    built_blocks[i].current_subtype = built_blocks[i].next_subtype
   else
    built_blocks[i].transformation_time -= delta_time
   end
  end 
 end
end
-------------------------------------------------------------------------------
-- apply the rules for all blocks
function _apply_wild_rule(rule)
 for i = 1, #built_blocks do
  if built_blocks[i].id == rule.id_target then
   --we test if this rule can apply on this block:
   if _pick_neighbours(built_blocks[i].x, built_blocks[i].y, rule.amount_neighbours, rule.id_neighbours, rule.required_tags) then
    --if the block isn't already transforming, we apply the rule:
    if built_blocks[i].subtype_priority < rule.priority then
     built_blocks[i].next_subtype = rule.id_self
     built_blocks[i].transformation_time = rule.time_to_grow
     built_blocks[i].subtype_priority = rule.priority
     built_blocks[i].tags = rule.rule_tags
    end
   end
  end
 end
end

__gfx__
990000000000009900000066660000000000000000000000000000ffff0000000000000000000000000000000000000000000000000000000000000000000000
9000000000000009000066666666000000000000000000000000ffffffff000000000dddddd0000000000dddddd0000000000dddddd0000000000dddddd00000
00000000000000000066666666666600000000cccc00000000ffffffffffff000000dddddddd00000000dd5555dd00000000dddddddd00000000dd5555dd0000
000000000000000006666666666666600000ccc7cccc00000ffffffffffffff0000ddd6666ddd000000dd566665dd000000ddd6666ddd000000dd566665dd000
0000000000000000046666666666664000cccccccc7ccc0005ffffffffffff5000ddd666666ddd0000dd56666665dd0000ddd666d66ddd0000dd56665665dd00
000000000000000004446666666644400ccccc7cccccccc00555ffffffff55500ddd66dddd66dddd0dd5665555665ddd0ddd66d66666ddd00dd5665666665dd0
9000000000000009044444666644444001cccccccccccc10055555ffff5555500dd66d6666d66ddd0d566566665665dd0dd666666d666dd00d566666656665d0
990000000000009904444444444444400111cccc7ccc111005555555555555500dd6d666666d6dd60d565666666565d60dd6666d66666dd00d566665666665d0
00000088880000000444444444444440011111cccc11111005555555555555500dd6dd6666dd6dd60d565566665565d60dd66dd666666dd00d566556666665d0
00008800008800000444444444444440011111111111111005555555555555500dd6dddddddd6dd60d565555555565d60dd6d66666666dd00d565666666665d0
00880080080088000444444444444440011111111111111005555555555555500dd6dddddddd6dd60d565555555565d60dd6d6dddddd6dd00d565655555565d0
08000008800000800444444444444440011111111111111005555555555555500dd66dddddd66dd60d566555555665d60dd66ddddddd6dd00d566555555565d0
00880080080088000444444444444440011111111111111005555555555555500dd666dddd666dd60d566655556665d60dd666dddddd6dd00d566655555565d0
00008800008800000044444444444400001111111111110000555555555555000dd6666666666dd60d566666666665d60dd6666666666dd00d566666666665d0
00000088880000000000444444440000000011111111000000005555555500000ddddddddddddddd0d555555555555dd0dddddddddddddd00d555555555555d0
00000000000000000000004444000000000000111100000000000055550000000ddddddddddddddd0ddddddddddddddd0dddddddddddddd00dddddddddddddd0
00000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000575000000000000dddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000057550000000000dddddddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000005777500000000ddd6666ddd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000005777775000000ddd666666ddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000577777500000ddd66666666ddd000000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddd00000000000000
00000057777500000dd6666666666dd000000000000000000000000000000000ddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000
00000005555000000dd6666666666dd0000000000000000000000000000000006666666655666655666666665566665566666666556666556dd0000000000000
00000005000000000dd6666666666dd0000000000000000000000000000000006663366656633665666cc666566cc665666ff666566ff6656dd0000000000000
00000057550000000dd6666666666dd000000000000000000000000000000000663333666633336666cccc6666cccc6666ffff6666ffff666dd0000000000000
00000057775000000dd6666666666dd0000000000000000000000000000000006643346666433466661cc166661cc166665ff566665ff5666dd0000000000000
00000577777500000dd6666666666dd0000000000000000000000000000000006644446666444466661111666611116666555566665555666dd0000000000000
00000577777500000dd6666666666dd0000000000000000000000000000000006664466656644665666116665661166566655666566556656dd0000000000000
00000057777500000dd6666666666dd0000000000000000000000000000000006666666655666655666666665566665566666666556666556dd0000000000000
00000005555000000dddddddddddddd000000000000000000000000000000000ddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000
00000000000000000dddddddddddddd000000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddd00000000000000
00000033330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00003333333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0033333333333300000000cccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03333333333333300000ccc7cccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
003333333333330000cccccccc7ccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00003333333300000ccccc7cccccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000333300000001cccccccccc7cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000111cccc7ccccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000033000000011111cccccccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000033000000000001111111ccccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000033003300001111111c7ccc7c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000330000000000001111111c7cccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000330000330001111111cccccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000030000300000000111111ccccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000001111ccc7ccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000011cccccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000003b33000b00000000000ccccc7cc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000b3343333bbb0000000000ccccc7cc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
003bbb333b33b4b000000000ccc7cccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
033b4b33bbb3343000000000ccc7ccc7cccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00334333b4b3330000000000cccccccccc7ccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000333334330000000000000ccccc7cccccccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000033330000000000000001cccccccccccc100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000111cccc7ccc11100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000011111cccc1111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000001111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000001111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000001111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000001111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000001111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1919191919191919191919191919191919191919191919191919191919191919191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1919191919191919191919191919191919191919191919191919191919191919191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1919191919191919191919191919191919191919191919191919191919191919191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1919191919191919191919191919191919191919191919191919191919191919191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1919191919191919191919191919191919191919191919191919191919191919191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1919191919191919191919191919191919191919191919191919191919191919191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1919191919191919191919191919191919191919191919191919191919191919191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1919191919191919191919191919191919191919191919191919191919191919191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1919191919191919191919191919191919191919191919191919191919191919191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1919191919191919191919191919191919191919191919191919191919191919191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1919191919191919191919191919191919191919191919191919191919191919191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1919191919191919191919191919191919191919191919191919191919191919191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1919191919191919191919191919191919191919191919191919191919191919191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1919191919191919191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

