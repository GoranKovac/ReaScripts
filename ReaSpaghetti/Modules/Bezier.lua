local min, max, sqrt, abs = math.min, math.max, math.sqrt, math.abs

local curve_recursion_limit = 64
local curve_flatness_epsilon = 1 * 2 ^ (-curve_recursion_limit - 1)


local function dot_product(ax, ay, bx, by) --the dot product of two vectors
    return ax * bx + ay * by
end

--distance between two points squared.
local function distance2(x1, y1, x2, y2)
    return (x2 - x1) ^ 2 + (y2 - y1) ^ 2
end

--split a 5th degree bezier at time t = 0.5 into two curves using De Casteljau interpolation (30 muls).
local function bezier5_split_in_half(x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, x6, y6)
    local x12 = (x1 + x2) / 2
    local y12 = (y1 + y2) / 2
    local x23 = (x2 + x3) / 2
    local y23 = (y2 + y3) / 2
    local x34 = (x3 + x4) / 2
    local y34 = (y3 + y4) / 2
    local x45 = (x4 + x5) / 2
    local y45 = (y4 + y5) / 2
    local x56 = (x5 + x6) / 2
    local y56 = (y5 + y6) / 2
    local x123 = (x12 + x23) / 2
    local y123 = (y12 + y23) / 2
    local x234 = (x23 + x34) / 2
    local y234 = (y23 + y34) / 2
    local x345 = (x34 + x45) / 2
    local y345 = (y34 + y45) / 2
    local x456 = (x45 + x56) / 2
    local y456 = (y45 + y56) / 2
    local x1234 = (x123 + x234) / 2
    local y1234 = (y123 + y234) / 2
    local x2345 = (x234 + x345) / 2
    local y2345 = (y234 + y345) / 2
    local x3456 = (x345 + x456) / 2
    local y3456 = (y345 + y456) / 2
    local x12345 = (x1234 + x2345) / 2
    local y12345 = (y1234 + y2345) / 2
    local x23456 = (x2345 + x3456) / 2
    local y23456 = (y2345 + y3456) / 2
    local x123456 = (x12345 + x23456) / 2
    local y123456 = (y12345 + y23456) / 2
    return
        x1, y1, x12, y12, x123, y123, x1234, y1234, x12345, y12345, x123456, y123456, --first curve
        x123456, y123456, x23456, y23456, x3456, y3456, x456, y456, x56, y56, x6, y6  --second curve
end

--compute intersection of chord from first control polocal to last with 0-axis.
local function bezier5_xintercept(x1, y1, x6, y6)
    local XLK = 1.0
    local YLK = 0.0
    local XNM = x6 - x1
    local YNM = y6 - y1
    local XMK = x1
    local YMK = y1
    local det = XNM * YLK - YNM * XLK
    local S = (XNM * YMK - YNM * XMK) * (1 / det)
    local X = 0.0 + XLK * S
    return X
end

--check if the control polygon of a Bezier curve is flat enough for recursive subdivision to bottom out.
local function bezier5_flat_enough(x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, x6, y6)
    --coefficients of implicit equation for line from (x1,y1)-(x6,y6).
    --derive the implicit equation for line connecting first and last control points.
    local a                  = y1 - y6
    local b                  = x6 - x1
    local c                  = x1 * y6 - x6 * y1

    local d1                 = a * x2 + b * y2 + c
    local d2                 = a * x3 + b * y3 + c
    local d3                 = a * x4 + b * y4 + c
    local d4                 = a * x5 + b * y5 + c
    local max_distance_below = min(0, d1, d2, d3, d4)
    local max_distance_above = max(0, d1, d2, d3, d4)

    --implicit equation for the zero line.
    local a1                 = 0.0
    local b1                 = 1.0
    local c1                 = 0.0

    --implicit equation for the "above" line.
    local a2                 = a
    local b2                 = b
    local c2                 = c - max_distance_above
    local det                = a1 * b2 - a2 * b1
    local intercept1         = (b1 * c2 - b2 * c1) * (1 / det)

    --implicit equation for the "below" line.
    local a2                 = a
    local b2                 = b
    local c2                 = c - max_distance_below
    local det                = a1 * b2 - a2 * b1
    local intercept2         = (b1 * c2 - b2 * c1) * (1 / det)

    --intercepts of the bounding box.
    local left_intercept     = min(intercept1, intercept2)
    local right_intercept    = max(intercept1, intercept2)

    local error              = right_intercept - left_intercept
    return error < curve_flatness_epsilon
end

local function bezier5_crossing_count(y1, y2, y3, y4, y5, y6)
    return
        ((y1 < 0) ~= (y2 < 0) and 1 or 0) +
        ((y2 < 0) ~= (y3 < 0) and 1 or 0) +
        ((y3 < 0) ~= (y4 < 0) and 1 or 0) +
        ((y4 < 0) ~= (y5 < 0) and 1 or 0) +
        ((y5 < 0) ~= (y6 < 0) and 1 or 0)
end

--given a 5th-degree equation in Bernstein-Bezier form, find and write all roots in the interval [0, 1].
local function bezier5_roots(write, x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, x6, y6, depth)
    local switch = bezier5_crossing_count(y1, y2, y3, y4, y5, y6)
    if switch == 0 then     --no solutions here
        return {}
    elseif switch == 1 then --unique solution
        --stop the recursion when the tree is deep enough and write the one solution at midpoint
        if depth >= curve_recursion_limit then
            write((x1 + x6) / 2)
            return
        end
        --stop the recursion when the curve is flat enough and write the solution at x-intercept
        if bezier5_flat_enough(x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, x6, y6) then
            write(bezier5_xintercept(x1, y1, x6, y6))
            return
        end
    end
    --otherwise, solve recursively after subdividing the control polygon
    local x1, y1, x12, y12, x123, y123, x1234, y1234, x12345, y12345, x123456, y123456,
    x123456, y123456, x23456, y23456, x3456, y3456, x456, y456, x56, y56, x6, y6 =
        bezier5_split_in_half(x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, x6, y6)
    bezier5_roots(write, x1, y1, x12, y12, x123, y123, x1234, y1234, x12345, y12345, x123456, y123456, depth + 1)
    bezier5_roots(write, x123456, y123456, x23456, y23456, x3456, y3456, x456, y456, x56, y56, x6, y6, depth + 1)
end

--precomputed "z" for cubics
local cubicz11, cubicz12, cubicz13, cubicz14 = 1.0, 0.6, 0.3, 0.1
local cubicz21, cubicz22, cubicz23, cubicz24 = 0.4, 0.6, 0.6, 0.4
local cubicz31, cubicz32, cubicz33, cubicz34 = 0.1, 0.3, 0.6, 1.0

local function bezier3_to_bezier5(x0, y0, x1, y1, x2, y2, x3, y3, x4, y4)
    --c's are vectors created by subtracting the polocal (x0,y0) from each of the control points.
    local c1x = x1 - x0
    local c1y = y1 - y0
    local c2x = x2 - x0
    local c2y = y2 - y0
    local c3x = x3 - x0
    local c3y = y3 - y0
    local c4x = x4 - x0
    local c4y = y4 - y0
    --d's are vectors created by subtracting each control polocal from the next and then scaling by 3.
    local d1x = 3 * (x2 - x1)
    local d1y = 3 * (y2 - y1)
    local d2x = 3 * (x3 - x2)
    local d2y = 3 * (y3 - y2)
    local d3x = 3 * (x4 - x3)
    local d3y = 3 * (y4 - y3)
    --the c x d table is a table of dot products of the c's and d's.
    local cd11 = dot_product(d1x, d1y, c1x, c1y)
    local cd12 = dot_product(d1x, d1y, c2x, c2y)
    local cd13 = dot_product(d1x, d1y, c3x, c3y)
    local cd14 = dot_product(d1x, d1y, c4x, c4y)
    local cd21 = dot_product(d2x, d2y, c1x, c1y)
    local cd22 = dot_product(d2x, d2y, c2x, c2y)
    local cd23 = dot_product(d2x, d2y, c3x, c3y)
    local cd24 = dot_product(d2x, d2y, c4x, c4y)
    local cd31 = dot_product(d3x, d3y, c1x, c1y)
    local cd32 = dot_product(d3x, d3y, c2x, c2y)
    local cd33 = dot_product(d3x, d3y, c3x, c3y)
    local cd34 = dot_product(d3x, d3y, c4x, c4y)
    --apply the z's to the dot products, on the skew diagonal.
    local y1 = cd11 * cubicz11
    local y2 = cd21 * cubicz21 + cd12 * cubicz12
    local y3 = cd31 * cubicz31 + cd22 * cubicz22 + cd13 * cubicz13
    local y4 = cd32 * cubicz32 + cd23 * cubicz23 + cd14 * cubicz14
    local y5 = cd33 * cubicz33 + cd24 * cubicz24
    local y6 = cd34 * cubicz34
    return
        0, y1,
        1 / 5, y2,
        2 / 5, y3,
        3 / 5, y4,
        4 / 5, y5,
        1, y6
end

--compute B(t) (see wikipedia).
local function value(t, x1, x2, x3, x4)
    return (1 - t) ^ 3 * x1 + 3 * (1 - t) ^ 2 * t * x2 + 3 * (1 - t) * t ^ 2 * x3 + t ^ 3 * x4
end

--evaluate a cubic bezier at time t using linear interpolation.
--for bit more speed, we could save and reuse the polynomial coefficients betwen computations for x and y.
local function point(t, x1, y1, x2, y2, x3, y3, x4, y4)
    return
        value(t, x1, x2, x3, x4),
        value(t, y1, y2, y3, y4)
end

--solve B(t)'=0 (use wolframalpha.com).
local function derivative1_roots(x1, x2, x3, x4)
    local base = -x1 * x3 + x1 * x4 + x2 ^ 2 - x2 * x3 - x2 * x4 + x3 ^ 2
    local denom = -x1 + 3 * x2 - 3 * x3 + x4
    if base > 0 and denom ~= 0 then
        local sq = sqrt(base)
        return
            (sq - x1 + 2 * x2 - x3) / denom,
            (-sq - x1 + 2 * x2 - x3) / denom
    else
        local denom = 2 * (x1 - 2 * x2 + x3)
        if denom ~= 0 then
            return (x1 - x2) / denom
        end
    end
end

--compute the minimum and maximum values for B(t).
local function minmax(x1, x2, x3, x4)
    --start off with the assumption that the curve doesn't extend past its endpoints.
    local minx = min(x1, x4)
    local maxx = max(x1, x4)
    --if the curve has local minima and/or maxima then adjust the bounding box.
    local t1, t2 = derivative1_roots(x1, x2, x3, x4)
    if t1 and t1 >= 0 and t1 <= 1 then
        local x = value(t1, x1, x2, x3, x4)
        minx = min(x, minx)
        maxx = max(x, maxx)
    end
    if t2 and t2 >= 0 and t2 <= 1 then
        local x = value(t2, x1, x2, x3, x4)
        minx = min(x, minx)
        maxx = max(x, maxx)
    end
    return minx, maxx
end


function HIT(x0, y0, x1, y1, x2, y2, x3, y3, x4, y4)
    --convert problem to 5th-degree Bezier form
    local ax1, ay1, ax2, ay2, ax3, ay3, ax4, ay4, ax5, ay5, ax6, ay6 =
        bezier3_to_bezier5(x0, y0, x1, y1, x2, y2, x3, y3, x4, y4)

    local mind, minx, miny, mint = 1 / 0 --shortest distance, touch point, and the parametric value for the touch point.

    --find all roots in [0, 1] interval for the 5th-degree equation and see which has the shortest distance.
    local function test_solution(t)
        assert(t >= 0 and t <= 1)
        local x, y = point(t, x1, y1, x2, y2, x3, y3, x4, y4)
        local d = distance2(x0, y0, x, y)
        if d < mind then
            mind, minx, miny, mint = d, x, y, t
        end
    end

    bezier5_roots(test_solution, ax1, ay1, ax2, ay2, ax3, ay3, ax4, ay4, ax5, ay5, ax6, ay6, 0)

    --also test distances to beginning and end of the curve, where t = 0 and 1 respectively.
    local d = distance2(x0, y0, x1, y1)
    if d < mind then
        mind, minx, miny, mint = d, x1, y1, 0
    end
    local d = distance2(x0, y0, x4, y4)
    if d < mind then
        mind, minx, miny, mint = d, x4, y4, 1
    end

    return mind, minx, miny, mint
end

--bounding box as (x, y, w, h)
function BOUNDING_BOX(x1, y1, x2, y2, x3, y3, x4, y4)
    local minx, maxx = minmax(x1, x2, x3, x4)
    local miny, maxy = minmax(y1, y2, y3, y4)
    return minx, miny, maxx - minx, maxy - miny
end
