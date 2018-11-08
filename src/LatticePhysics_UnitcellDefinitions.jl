################################################################################
#
#   module LatticePhysics_UnitcellDefinitions
#   -> LatticePhysics_Base
#   -> LinearAlgebra
#
#   --> PRE-IMPLEMENTED UNITCELLS 2D
#
#   --> PRE-IMPLEMENTED UNITCELLS 3D
#
################################################################################

# TODO LIST
# --> TRY CATCH to DISPATCH AND FALLBACK for Val{T} where T
# --> TODO common interface getUnitcell(:square)
# --> TODO version vs. implementation
# --> version is not a keyword argument
# --> TODO UnitcellDefinitions -> UnitcellLibrary

# module start
# module LatticePhysics_UnitcellDefinitions



# include interface
include("LatticePhysics_UnitcellDefinitions/interface.jl")



# include 2d stuff
include("LatticePhysics_UnitcellDefinitions/definitions_2d.jl")

# include 3d stuff
include("LatticePhysics_UnitcellDefinitions/definitions_3d.jl")



# module end
# module end
