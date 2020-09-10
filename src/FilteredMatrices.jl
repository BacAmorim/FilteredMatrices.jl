module FilteredMatrices

using LinearAlgebra, LinearMaps, UnPack

export delta

function delta(H::AbstractMatrix{T}, ε; range = bandrange(H), order = defaultorder(H)) where {T<:Number}
    M, N = size(H)
    bracket = bandbracket(range)
    v = Vector{T}(undef, N)
    v´ = Vector{T}(undef, N)
    args = (H = H, ε = ε, bracket = bracket, order = order, v = v, v´ = v´)
    LinearMap{T}((vdst, v0) -> delta_mul!(vdst, v0, args), M, N; ismutating = true, ishermitian = true)
end

bandrange(H) = (-1, 1)

bandbracket((εmin, εmax)) = (εmax + εmin)/2, abs(εmax - εmin)

defaultorder(H) = 10 #round(Int, sqrt(size(H,1)))

function delta_mul!(vdst::AbstractVector{T}, v0, args) where {T}
    @unpack H, ε, bracket, order, v, v´ = args

    # We use adjoint of CSC matrix to accelerate multiplication
    H´ = H'
    center, halfwidth = bracket
    α = 2/halfwidth
    β = 2center/halfwidth
    σ = (ε - center)/halfwidth
    ρ = 1/(pi*sqrt(1-σ^2))

    # t and t´ are used to build tn = ρ Tn(σ) recurseively
    t  = ρ
    t´ = σ * t

    # v and v´ are used to build vn = Tn(h)⋅v recursively, where h = (H-center)/halfwidth
    @. v = v0
    fill!(v´, zero(T))
    nextCheby!(v´, H´, v, α, β)

    # vdst accumulates delta(σ-H) * v ≈ ρ (v + 2∑ Tn(σ)Tn(h)⋅v) = t0 v0 + 2 ∑ tn vn
    @. vdst = t * v + 2t´ * v´

    for n in 3:(order+1)
        nextCheby!(v, H´, v´, α, β)
        t = nextCheby(t, σ, t´)
        @. vdst += 2 * t * v
        v´, v = v, v´
        t´, t = t, t´
    end
    return vdst
end

function nextCheby!(v´, H´, v, α, β)
    mul!(v´, H´, v, α, -1)
    @. v´ -= β * v
    return v´
end

nextCheby(t´, σ, t) = 2σ * t - t´

end # module