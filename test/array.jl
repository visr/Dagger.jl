import ComputeFramework: parts, parts, Computed

parts(x::Computed) = parts(x.result)
parts(x::Computed) = parts(x.result)
ComputeFramework.domain(x::Computed) = domain(x.result)

@testset "Arrays" begin

@testset "rand" begin
    function test_rand(X)
        X1 = compute(X)
        X2 = gather(X1)

        @test isa(X, ComputeFramework.Computation)
        @test isa(X1, ComputeFramework.Computed)
        @test isa(X1.result, ComputeFramework.Cat)
        @test X2 |> size == (100, 100)
        @test all(X2 .>= 0.0)
        @test size(parts(X1)) == (10, 10)
        @test domain(X1).head == DenseDomain(1:100, 1:100)
        @test parts(domain(X1)) |> size == (10, 10)
        @test parts(domain(X1)) == parts(partition(BlockPartition(10, 10), DenseDomain(1:100, 1:100)))
    end
    X = rand(BlockPartition(10, 10), 100, 100)
    test_rand(X)
    Xsp = sprand(BlockPartition(10, 10), 100, 100, 0.1)
    test_rand(Xsp)
end
@testset "sum(ones(...))" begin
    X = ones(BlockPartition(10, 10), 100, 100)
    @test compute(sum(X)) == 10000
end


@testset "distributing an array" begin
    function test_dist(X)
        X1 = Distribute(BlockPartition(10, 20), X)
        @test gather(X1) == X
        Xc = compute(X1)
        @test parts(Xc) |> size == (10, 5)
        @test parts(domain(Xc)) |> size == (10, 5)
        @test map(x->size(x) == (10, 20), parts(domain(Xc))) |> all
    end
    test_dist(rand(100, 100))
    test_dist(sprand(100, 100, 0.1))
end

@testset "transpose" begin
    function test_transpose(X)
        x, y = size(X)
        X1 = Distribute(BlockPartition(10, 20), X)
        @test gather(X1') == X'
        Xc = compute(X1')
        @test parts(Xc) |> size == (div(y, 20), div(x,10))
        @test parts(domain(Xc)) |> size == (div(y, 20), div(x, 10))
        @test map(x->size(x) == (20, 10), parts(domain(Xc))) |> all
    end
    test_transpose(rand(100, 100))
    test_transpose(rand(100, 120))
    test_transpose(sprand(100, 100, 0.1))
    test_transpose(sprand(100, 120, 0.1))
end

@testset "matrix-matrix multiply" begin
    function test_mul(X)
        tol = 1e-12
        X1 = Distribute(BlockPartition(10, 20), X)
        @test_throws DimensionMismatch compute(X1*X1)
        X2 = compute(X1'*X1)
        X3 = compute(X1*X1')
        @test norm(gather(X2) - X'X) < tol
        @test norm(gather(X3) - X*X') < tol
        @test parts(X2) |> size == (2, 2)
        @test parts(X3) |> size == (4, 4)
        @test map(x->size(x) == (20, 20), parts(domain(X2))) |> all
        @test map(x->size(x) == (10, 10), parts(domain(X3))) |> all
    end
    test_mul(rand(40, 40))

    x = rand(10,10)
    X = Distribute(BlockPartition(3,3), x)
    y = rand(10)
    @test norm(gather(X*y) - x*y) < 1e-13
end

@testset "concat" begin
    m = rand(75,75)
    x = Distribute(BlockPartition(10,20), m)
    y = Distribute(BlockPartition(10,10), m)
    @test hcat(m,m) == gather(hcat(x,x))
    @test vcat(m,m) == gather(vcat(x,x))
    @test hcat(m,m) == gather(hcat(x,y))
    @test_throws DimensionMismatch compute(vcat(x,y))
end

@testset "scale" begin
    x = rand(10,10)
    X = Distribute(BlockPartition(3,3), x)
    y = rand(10)

    @test Diagonal(y)*x == gather(scale(y, X))
end

@testset "Getindex" begin
    function test_getindex(x)
        X = Distribute(BlockPartition(3,3), x)
        @test gather(X[3:8, 2:7]) == x[3:8, 2:7]
        ragged_idx = [1,2,9,7,6,2,4,5]
        @test gather(X[ragged_idx, 2:7]) == x[ragged_idx, 2:7]
        @test gather(X[ragged_idx, reverse(ragged_idx)]) == x[ragged_idx, reverse(ragged_idx)]
        ragged_idx = [1,2,9,7,6,2,4,5]
        @test gather(X[[2,7,10], :]) == x[[2,7,10], :]
        @test gather(X[[], ragged_idx]) == x[[], ragged_idx]
        @test gather(X[[], []]) == x[[], []]

        @testset "dimensionality reduction" begin
        # THESE NEED FIXING!!
            @test vec(gather(X[ragged_idx, 5])) == vec(x[ragged_idx, 5])
            @test vec(gather(X[5, ragged_idx])) == vec(x[5, ragged_idx])
            @test gather(X[5, 5])[1] == x[5,5]
        end
    end

    test_getindex(rand(10,10))
    test_getindex(sprand(10,10,0.5))
end

end
