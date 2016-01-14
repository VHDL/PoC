# load XDC file defining the clocks before this XDC file
set_property ASYNC_REG true [get_cells -regexp {gen\[\d+\]\.Sync/FF2}]
set_property ASYNC_REG true [get_cells -regexp {gen\[\d+\]\.Sync/FF1_METASTABILITY_FFS}]
set_false_path -from [get_clocks] -to [get_cells -regexp {gen\[\d+\]\.Sync/FF1_METASTABILITY_FFS}]
