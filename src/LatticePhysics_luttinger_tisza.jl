################################################################################
#
#   METHODS FOR LUTTINGER TISZA CALCULATION
#
#   STRUCTURE OF THE FILE
#
#   1) TYPE LTBANDSTRUCTURE
#       - type definition
#       - printInfo function
#
#   2) CALCULATION OF LT BAND STRUCTURES OF UNTICELL OBJECTS
#      (- LT constraint and deviation functions (NOT EXPORTED) )
#       - spin interaction matrices
#       - calculation of band structures
#
#   3) PLOTTING OF LT BAND STRUCTURES
#       - plotting of Bandstructure objects
#       - plotting of bandstructures of unitcells along paths
#
#   4) TODO CALCULATION OF LT GROUND STATES (k space manifold)
#
#   5) TODO PLOTTING OF LT GROUND STATES (k space manifold)
#       - TODO plotting from points
#       - TODO plotting from unitcell
#
################################################################################






################################################################################
#
#   TYPE LTBANDSTRUCTURE
#       - type definition
#       - printInfo function
#
################################################################################
"""
    struct LTBandstructure

The type that contains information on a Luttinger Tisza band structure (energy values in momentum space with spin constraints).
Fields are

    path              :: Path
    bands             :: Array{Array{Array{Float64, 1}, 1}, 1}
    constraint_values :: Array{Array{Array{Float64, 1}, 1}, 1}

Note that the notation of `bands` (and `constraint_values`) is the following:
- `bands[i]`       gives all bands of path segment `i`
- `bands[i][j]`    gives all energy values for band `j` of path segment `i`
- `bands[i][j][k]` gives the energy value at kpoint index `k` of band `j` in path segment `i`

The `constraint_values` carry the minimal deviation from unit spin length within the unitcell, i.e.
value is the minimum of all sum(|s_i - 1.0|^2) for constructed s_i.

New `LTBandstructure` objects can be created only by the default constructor or one of
the several functions to calculate LT band structures.




# Examples

```julia-repl
julia> bandstructure = LTBandstructure(path, bands, constraint_values)
LatticePhysics.LTBandstructure(...)
```
"""
struct LTBandstructure

    # the path along which the band structure is calcualted
    path::Path

    # bands for each segment
    # bands[i] gives all bands of segment i
    # bands[i][j] gives all energy values for band j of segment i
    # bands[i][j][k] gives the energy value at kpoint index k of band j in segment i
    bands::Array{Array{Array{Float64, 1}, 1}, 1}

    # constraint value for all bands
    # value is the minimum of all sum(|s_i - 1.0|^2) for constructed s_i
    constraint_values::Array{Array{Array{Float64, 1}, 1}, 1}

    # ONLY DEFAULT CONSTRUCTOR

end


# export the type
export LTBandstructure






# INFORMATION FUNCTION
"""
    printInfo(bandstructure::LTBandstructure [; constraint::Float64=1e-6])

Prints information about a `LTBandstructure` in terms of
how many eigenvalues of the contained bands satisfy the LT constraint in which region of the path.
The `constraint` parameter allows to sharpen or soften the distinction between constraint
fullfilling and constraint breaking eigenvalues.




# Examples

```julia-repl
julia> printInfo(bandstructure)
...

julia> printInfo(unitcell, constraint=1e-8)
...

```
"""
function printInfo(bandstructure::LTBandstructure; constraint::Float64=1e-6)
    # print the header
    println("Bandstructure (LT), constraint satisfied for var(length) < $(constraint)")
    print("\t$(bandstructure.path.point_names[1])")
    for p in bandstructure.path.point_names[2:end]
        print("\t->-\t$(p)")
    end
    println("")
    # print each band
    for b in 1:length(bandstructure.bands[1])
        # first the point
        print("$(b))\t|")
        # then all segments with closing points
        for s in 1:length(bandstructure.bands)
            # segment s starts
            print("\t")
            # calculate the number of constraint fullfilling values
            print("$(round(100.0*sum([c>constraint ? 0 : 1 for c in bandstructure.constraint_values[s][b]])/length(bandstructure.constraint_values[s][b]),2))%")
            # print the next point
            print("\t|")
        end
        # print a new line
        println("")
    end
end















# INTERNAL FUNCTIONS CONCERNING THE CONSTRAINT IN THE LT CALCULATION
# (not exported)

# function to calculate the deviation from best result
function deviation(spin_eigenvectors::Array{Array{Complex{Float64},1},1}, spin_dimension::Int64, alpha::Array{Float64,1})
    # build up the global spin vector
    spin_vector = zeros(length(spin_eigenvectors[1]))
    for s in 1:length(spin_eigenvectors)
        spin_vector = spin_vector .+ alpha[s].*spin_eigenvectors[s]
    end
    # find out the individual lengths of spins
    spin_lengths = spin_vector .* conj.(spin_vector)
    spin_lengths = [sum(spin_lengths[s:s+spin_dimension-1]) for s in 1:spin_dimension:length(spin_lengths)]
    # find out the deviation from unity
    dl = sum(abs.((spin_lengths .- 1)))
    return dl
end

# Definition of constraint
function getLTConstraint(spin_eigenvectors::Array{Array{Complex{Float64},1},1}, spin_dimension::Int64)
    # detrmine what to do based on the number of eigenvectors
    if length(spin_eigenvectors) == 1
        # find out the individual lengths of spins
        spin_lengths = spin_eigenvectors[1] .* conj.(spin_eigenvectors[1])
        spin_lengths = [sum(spin_lengths[s:s+spin_dimension-1]) for s in 1:spin_dimension:length(spin_lengths)]
        # find out the deviation from unity
        dl = sum(abs.((spin_lengths .- mean(spin_lengths))))
    else
        # optimize the function
        return Optim.minimum(Optim.optimize(x -> deviation(spin_eigenvectors, spin_dimension, x), ones(length(spin_eigenvectors))))
    end
end




################################################################################
#
#   INTERACTION MATRICES FOR SPIN SYSTEMS
#   - bond interaction matrices
#   - global interaction matrix (for the unitcell)
#
################################################################################

# Function to create a bond strength matrix
"""
    getBondInteractionMatrixHeisenbergKitaev(connection::Array{Any,1})

Constructs the spin interaction matrix for a single bond given by `connection`.
The matrix is of size 3x3 and is of type `Array{Float64,2}`, i.e. it has real entries.
Depending on the parameter of the bond strength (i.e. `c[3]`), it chooses to return a different matrix.
The replaced strings contain
- `"J1"`,`"J2"` --> Heisenberg type, strength 1.0
- `"Jx"`,`"Jy"`,`"Jz"`,`"tx"`,`"tx"`,`"tx"` --> Kitaev type, strength 1.0

Otherwise, the matrix has entries `matrix[i,i] = c[3]`




# Examples

```julia-repl
julia> getBondInteractionMatrixHeisenbergKitaev(Any[1,2, "tx", (0,0,0)])
3×3 Array{Float64,2}:
 1.0  0.0  0.0
 0.0  0.0  0.0
 0.0  0.0  0.0

julia> getBondInteractionMatrixHeisenbergKitaev(Any[1,2, "J1", (0,0,0)])
3×3 Array{Float64,2}:
 1.0  0.0  0.0
 0.0  1.0  0.0
 0.0  0.0  1.0

```
"""
function getBondInteractionMatrixHeisenbergKitaev(connection::Array{Any,1})
    # new 3x3 matrix
    bond_matrix = zeros(3,3)
    # get the bond strength
    strength = connection[3]
    # check what type the bond is
    if typeof(strength) == String
        if strength == "J1"
            bond_matrix[1,1] = 1.0
            bond_matrix[2,2] = 1.0
            bond_matrix[3,3] = 1.0
        elseif strength == "J2"
            bond_matrix[1,1] = 1.0
            bond_matrix[2,2] = 1.0
            bond_matrix[3,3] = 1.0
        elseif strength == "Jx" || strength == "tx"
            bond_matrix[1,1] = 1.0
        elseif strength == "Jy" || strength == "ty"
            bond_matrix[2,2] = 1.0
        elseif strength == "Jz" || strength == "tz"
            bond_matrix[3,3] = 1.0
        end
    else
        bond_matrix[1,1] = strength
        bond_matrix[2,2] = strength
        bond_matrix[3,3] = strength
    end
    # return the matrix
    return bond_matrix
end
export getBondInteractionMatrixHeisenbergKitaev

"""
    getBondInteractionMatrixHeisenberg(connection::Array{Any,1})

Constructs the spin interaction matrix for a single bond given by `connection`.
The matrix is of size 1x1 and is of type `Array{Float64,2}`, i.e. it has only one (real) entry.
Depending on the parameter of the bond strength (i.e. `c[3]`), it chooses to return a different matrix.
The replaced strings contain
- `"J1"`,`"J2"` --> Heisenberg type, strength 1.0

Otherwise, the matrix has entry `matrix[i,i] = c[3]`


# Examples

```julia-repl

julia> getBondInteractionMatrixHeisenberg(Any[1,2, "J1", (0,0,0)])
1×1 Array{Float64,2}:
 1.0

julia> getBondInteractionMatrixHeisenberg(Any[1,2, 3.0, (0,0,0)])
1×1 Array{Float64,2}:
 3.0
```
"""
function getBondInteractionMatrixHeisenberg(connection::Array{Any,1})
    # new 3x3 matrix
    bond_matrix = zeros(1,1)
    # get the bond strength
    strength = connection[3]
    # check what type the bond is
    if typeof(strength) == String
        if strength == "J1"
            bond_matrix[1,1] = 1.0
        elseif strength == "J2"
            bond_matrix[1,1] = 1.0
        end
    else
        bond_matrix[1,1] = strength
    end
    # return the matrix
    return bond_matrix
end
export getBondInteractionMatrixHeisenberg





# Function to produce interaction matrices for entire unitcell
"""
    getSpinInteractionMatrixKSpace(
        unitcell::Unitcell,
        k_vector::Array{Float64,1},
     [  bondInteractionMatrix::Function
      ; enforce_hermitian::Bool=false ]
    )

Constructs the spin interaction matrix (in *momentum* space at point `k_vector`)
for use in a Luttinger Tisza calculation of a given `Unitcell` object.
The matrix is a sNxsN matrix where N is the number of sites in the given object and s is the spin dimension.
Entries (i+s,j+s') contain the interactions between sites i and j and spin components s and s' as well as the phase factor exp(i k*delta).

The matrix is of type `Array{Complex,2}`, i.e. it has complex entries to account for the phase factor.

The precise form of the spin interaction along a bond is given by the function `bondInteractionMatrix`
(which has the default of giving 1x1 matrices with strength = c[3] for connections c).
This function can be customised along the format f(connection) = matrix.
The default of this function is `getBondInteractionMatrixHeisenberg`.

Note that it is a possibility to add custom parameters by distinguishing different bond types based on
their `String` valued strength but then returning a matrix of `Float64` entries.






# Examples

```julia-repl
julia> getSpinInteractionMatrixKSpace(unitcell, k)
2×2 Array{Complex,2}:
...

julia> getSpinInteractionMatrixKSpace(unitcell, [pi/2.0, 0.0])
2×2 Array{Complex,2}:
...

julia> getSpinInteractionMatrixKSpace(unitcell, [pi/2.0, 0.0], c->diagm([ c[3], c[3] ]))
4×4 Array{Complex,2}:
...
```
"""
function getSpinInteractionMatrixKSpace(unitcell::Unitcell, k_vector::Array{Float64,1}, bondInteractionMatrix::Function)
    # get the spin dimension
    spin_dimension = size(bondInteractionMatrix(unitcell.connections[1]), 1)
    # create a new matrix
    matrix = zeros(Complex, spin_dimension*length(unitcell.basis), spin_dimension*length(unitcell.basis))
    # iterate over all connections
    for c in unitcell.connections
        # get the indices
        index_from  = Int(c[1])
        index_to    = Int(c[2])
        strength    = c[3]
        wrap        = c[4]
        # get the difference vector
        pos_delta   = unitcell.basis[index_to] .- unitcell.basis[index_from]
        if size(unitcell.lattice_vectors,1) > 0
            for pair in zip(wrap, unitcell.lattice_vectors)
                pos_delta .+= pair[1].*pair[2]
            end
        end
        # get the bond interaction matrix
        bond_interaction_matrix = bondInteractionMatrix(c)
        # add to the complete matrix twice
        for i in 1:spin_dimension
        for j in 1:spin_dimension
            matrix[(index_from-1)*spin_dimension + i, (index_to-1)*spin_dimension + j] += 0.5 * bond_interaction_matrix[i,j] * exp(-im * sum(pos_delta .* k_vector))
            matrix[(index_to-1)*spin_dimension + j, (index_from-1)*spin_dimension + i] += 0.5 * bond_interaction_matrix[i,j] * exp( im * sum(pos_delta .* k_vector))
        end
        end
    end
    # return the matrix
    return matrix
end
export getSpinInteractionMatrixKSpace








################################################################################
#
#   BAND STRUCTURE CALCULATION
#
################################################################################
"""
    getLTBandstructure(
                unitcell::Unitcell,
                path::Path,
                bondInteractionMatrix::Function
             [; resolution::Int64=-1,
                enforce_hermitian::Bool=false ]
            )

Calculates the Luttinger Tisza band struture of a `Unitcell` object
along some path given by a `Path` object and returns a `LTBandstructure` object.

Note 1: Optionally a bond interaction matrix can be given as a function
that constructs a matrix for a passed bond argument. If this function is not passed,
the default function will be used.

Note 2: The bond interaction matrix specifies the dimension of interacting spins.





# Examples

```julia-repl
julia> bandstructure = getLTBandstructure(unitcell, path)
LatticePhysics.LTBandstructure(...)

julia> bandstructure = getLTBandstructure(unitcell, path, resolution=1000)
LatticePhysics.LTBandstructure(...)
```
"""
function getLTBandstructure(
                unitcell::Unitcell,
                path::Path,
                bondInteractionMatrix::Function = getBondInteractionMatrixHeisenberg;
                resolution::Int64=-1,
                enforce_hermitian::Bool=false,
                epsilon_degenerate::Float64=1e-6
            )

    # maybe modify the path resolution
    if resolution > 0
        setTotalResolution!(path, resolution)
    end

    # build up the list of all bands of all segments (and all constraints)
    segments_total    = Array{Array{Float64,1},1}[]
    constraints_total = Array{Array{Float64,1},1}[]

    # get the spin dimension
    spin_dimension = size(bondInteractionMatrix(unitcell.connections[1]), 1)
    # iterate over all path segments and push empty lists into the segments list
    for i in 1:length(path.segment_resolution)
        # build an empty band structure for this segment
        segment     = Array{Float64, 1}[]
        constraints = Array{Float64, 1}[]
        for b in 1:length(unitcell.basis)*spin_dimension
            push!(segment,     zeros(Float64, path.segment_resolution[i]))
            push!(constraints, zeros(Float64, path.segment_resolution[i]))
        end
        # push the segment band structure into the complete segment list
        push!(segments_total,    segment)
        push!(constraints_total, constraints)
    end


    # iterate over all segments
    for s in 1:length(path.segment_resolution)
        # get the grid in between two points
        segment_resolution = path.segment_resolution[s]
        # get all multipliers of k vectors (i.e. all alpha in (1-alpha)*k_1 + alpha*k_2)
        multipliers = linspace(0, 1, segment_resolution)
        # get the local start and end point of the segment
        k1 = path.points[s]
        k2 = path.points[s+1]
        # calculate all energies
        for i in 1:segment_resolution
            # get the current k
            k = (k2 .* multipliers[i]) .+ (k1 .* (1-multipliers[i]))
            # get the interaction matrix for this k
            matrix = getSpinInteractionMatrixKSpace(unitcell, k, bondInteractionMatrix)
            # diagonalize the matrix
            eigenfactorization = eigfact(matrix)
            eigenvalues  = eigenfactorization[:values]
            eigenvectors = eigenfactorization[:vectors]
            # save all the eigenvalues to their lists
            for b in 1:length(eigenvalues)
                segments_total[s][b][i] = eigenvalues[b]
            end
            # compute the constraint, first find out what bands are degenerate
            # list of bands they are degenerate with
            degenerate = zeros(Int64,   length(eigenvalues)) .- 1
            treat      = zeros(Int64,   length(eigenvalues))
            for b in 2:length(eigenvalues)
                # treat the current band
                treat[b] = 1
                # check if degenerate
                if eigenvalues[b] - epsilon_degenerate <= eigenvalues[b-1]
                    # band b is degenerate with band b-1
                    degenerate[b-1] = b
                    # dont treat the band as it is treated before
                    treat[b] = 0
                end
            end
            # iterate over all bands
            for b in 1:length(eigenvalues)
                # if not treated, continue
                if treat[b] == 0
                    continue
                end
                # if treated, compile list of all bands
                degenerate_bands = Int64[b]
                while degenerate[degenerate_bands[end]] != -1
                    push!(degenerate_bands, degenerate[degenerate_bands[end]])
                end
                # get the LT constraint
                LT_constraint = getLTConstraint([eigenvectors[:,j] for j in degenerate_bands], spin_dimension)
                # save the constraint
                for d in degenerate_bands
                    constraints_total[s][d][i] = LT_constraint
                end
            end
        end
    end

    # generate a new LT band structure object
    bandstructure = LTBandstructure(path, segments_total, constraints_total)

    # return the LT band structure
    return bandstructure
end
export getLTBandstructure












################################################################################
#
#   BAND STRUCTURE PLOTTING
#
################################################################################


"""
    plotLTBandstructure(
            bandstructure::LTBandstructure
         [; constraint::Float64=1e-6
            limits_energy="AUTO",
            plot_title::String="",
            plot_color="b",
            figsize::Tuple=(6,4),
            showPlot::Bool=true,
            save_filename::String="NONE" ]
            )

    plotLTBandstructure(
            unitcell::Unitcell,
            path::Path,
         [  bondInteractionMatrix::Function
          ; resolution::Int64=-1,
            enforce_hermitian::Bool=false,
            ... ]
        )


Plots the Luttinger Tisza band struture of a passed `LTBandstructure` object along some its path
and returns the plot as a `PyPlot.Figure` object.
Alternatively, one can pass a `Unitcell` and `Path` (and optionally a bond matrix function)
to calculate the Luttinger Tisza band structure which is plotted.

Additional options include setting the LT constraint,
plotting related options of `PyPlot` as well as determining if the plot is saved or shown.


# Examples

```julia-repl
julia> plotLTBandstructure(unitcell, path)
PyPlot.Figure(...)

julia> plotLTBandstructure(unitcell, path, c->diagm([ c[3] ]))
PyPlot.Figure(...)

julia> plotLTBandstructure(unitcell, path, showPlot=false)
PyPlot.Figure(...)

julia> plotLTBandstructure(unitcell, save_filename="myplot.pdf")
PyPlot.Figure(...)

julia> plotLTBandstructure(bandstructure)
PyPlot.Figure(...)
```
"""
function plotLTBandstructure(
            bandstructure::LTBandstructure;
            constraint::Float64=1e-6,
            limits_energy="AUTO",
            plot_title::String="",
            plot_color_valid="b",
            plot_color_invalid="r",
            figsize::Tuple=(6,4),
            showPlot::Bool=true,
            save_filename::String="NONE"
        )

    ###########################
    #   INITIAL SETTINGS
    ###########################

    # get the path from the bandstructure
    path = bandstructure.path

    # configure plot environment
    rc("font", family="serif")

    # create a new figure
    fig = figure(figsize=figsize)




    ###########################
    #   PLOT BANDS
    ###########################

    # plot the band structure
    for s in 1:length(bandstructure.bands)
        # plot the segment (only invalid stuff)
        for b in 1:length(bandstructure.bands[s])
            # xvalues
            xvals = collect(1:path.segment_resolution[s]) .+ sum(path.segment_resolution[1:s-1])
            yvals = bandstructure.bands[s][b]
            # check which values satisfy the constraint
            invalid_indices = collect(1:path.segment_resolution[s])[bandstructure.constraint_values[s][b] .>= constraint]
            # if no invalid indices are found, just skip
            if length(invalid_indices) == 0
                continue
            end
            # plot everything
            plot(
                [xvals[i] for i in invalid_indices],
                [yvals[i] for i in invalid_indices],
                ".$(plot_color_invalid)"
            )
        end
        # plot the segment (only valid stuff)
        for b in 1:length(bandstructure.bands[s])
            # xvalues
            xvals = collect(1:path.segment_resolution[s]) .+ sum(path.segment_resolution[1:s-1])
            yvals = bandstructure.bands[s][b]
            # check which values satisfy the constraint
            valid_indices   = collect(1:path.segment_resolution[s])[bandstructure.constraint_values[s][b] .< constraint]
            # if no valid indices are found, just skip
            if length(valid_indices) == 0
                continue
            end
            # plot everything
            plot(
                [xvals[i] for i in valid_indices],
                [yvals[i] for i in valid_indices],
                ".$(plot_color_valid)"
            )
        end
    end



    ###########################
    #   SET ALL TICKS (POINTS)
    ###########################

    # get the current axis
    ax = gca()
    axx = ax[:get_xaxis]()
    # compile tick positions and labels
    point_pos = Int64[]
    push!(point_pos, 1)
    for l in 1:length(path.segment_resolution)
        push!(point_pos, sum(path.segment_resolution[1:l]))
    end
    point_labels = String[path.point_names[i] for i in 1:length(path.points)]
    # configure tick labels
    xticks(point_pos, point_labels)
    # configure ticks
    axx[:set_tick_params](which="both", direction="out")
    axx[:set_tick_params](which="top", color="none")
    axy = ax[:get_yaxis]()
    axy[:set_tick_params](which="both", direction="out")

    # plot vertical lines for each point
    for p in point_pos
        axvline(p,color=[0.6, 0.6, 0.6], linestyle="--")
    end


    ###########################
    #   CONFIGURE AXIS & TITLE
    ###########################

    # label the axis
    xlabel("momentum")
    ylabel("energy")

    # energy limits
    # check if specific boundaries are desired
    if !(limits_energy == "AUTO")
        ylim(limits_energy[1], limits_energy[2])
    end

    # momentum limits (x axis)
    xlim(0, maximum(point_pos)+1)

    # set the title
    if plot_title == "AUTO"
        # set the title to an automatically generated title
        title("Luttinger Tisza spectrum along $(getPathString(path)), constraint $(constraint)")
    elseif plot_title == ""
        # do nothing title related
    else
        # set the title to the given title
        title(plot_title)
    end





    ###########################
    #   FINISH THE PLOT
    ###########################

    # tighten the layout
    tight_layout()

    # save the plot
    if save_filename != "NONE"
        # make sure the directory exists
        if contains(save_filename, "/")
    		# get the containing folder
    		folder = save_filename[1:findlast(save_filename, '/')]
    		# build the path to that folder
    		mkpath(folder)
    	end
        # save the plot
        savefig(save_filename)
    end

    # maybe show the plot
    if showPlot
        show()
    end

    # return the figure object
    return fig
end
function plotLTBandstructure(
            unitcell::Unitcell,
            path::Path,
            bondInteractionMatrix::Function = getBondInteractionMatrixHeisenberg;
            constraint::Float64=1e-6,
            resolution::Int64=-1,
            enforce_hermitian::Bool=false,
            limits_energy="AUTO",
            plot_title::String="",
            plot_color_valid="b",
            plot_color_invalid="r",
            figsize::Tuple=(6,4),
            showPlot::Bool=true,
            save_filename::String="NONE"
        )
    # calculate the bandstructure
    bandstructure = getLTBandstructure(unitcell, path, bondInteractionMatrix, resolution=resolution, enforce_hermitian=enforce_hermitian)
    # call the respective function
    return plotLTBandstructure(
                bandstructure;
                constraint=constraint,
                limits_energy=limits_energy,
                plot_title=plot_title,
                plot_color_valid=plot_color_valid,
                plot_color_invalid=plot_color_invalid,
                figsize=figsize,
                showPlot=showPlot,
                save_filename=save_filename
            )
end
export plotBandstructure
