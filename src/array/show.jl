
showsz(sz) = join(sz, "x")
function Base.show(io::IO, c::Cat)
    write(io, showsz(size(domain(c))))
    write(io, ' ')
    write(io, string(parttype(c)))
    write(io, " in ")
    write(io, showsz(size(parts(c))))
    write(io, " parts")
end