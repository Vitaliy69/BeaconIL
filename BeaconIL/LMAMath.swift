//
//  LMAMath.swift
//  BeaconIL
//
//  Created by Vitaliy Gribko on 18.03.2021.
//
//  Solves a formulation of n-D space trilateration problem
//  using a nonlinear least squares optimizer. Uses Levenberg-Marquardt algorithm.
//

import Foundation

class LMAMath {
    
    private enum LMAMathError: Error {
        case costRelativeTolerance
        case parRelativeTolerance
        case orthoTolerance
        case maxEvaluations
        case maxIterations
    }
    
    private struct Optimum {
        static let maxEvaluations = 1000
        static let maxIterations = 1000
        
        var target: [Double] = []
        var weightSquareRoot: [Double] = []
        var start: [Double] = []
    }
    
    private struct Evaluation {
        var jacobian: [[Double]] = []
        var residuals: [Double] = []
        var point: [Double] = []
    }
    
    private struct InternalData {
        var weightedJacobian: [[Double]]
        var permutation: [Int]
        var rank: Int
        var diagR: [Double]
        var jacNorm: [Double]
        var beta: [Double]
    }
    
    private var positions: [[Double]] = []
    private var distances: [Double] = []
    
    func solve(positions: [[Double]], distances: [Double]) -> [Double] {
        guard positions.count > 2 && distances.count > 2 && positions.count == distances.count else {
            return [Double]()
        }
        
        let numberOfPositions = positions.count
        let positionDimension = positions[0].count
        
        let coordinates = positions.lazy.map { $0 }
        for i in 0..<coordinates.count {
            if coordinates[i].count != positionDimension {
                return [Double]()
            }
        }
        
        self.positions = positions
        self.distances = distances
        
        // Initial point, use average of the vertices
        var initialPoint = Array(repeating: 0.0, count: positionDimension)
        for i in 0..<positions.count {
            let vertex = positions[i]
            for j in 0..<vertex.count {
                initialPoint[j] += vertex[j]
            }
        }
        
        for j in 0..<initialPoint.count {
            initialPoint[j] /= Double(numberOfPositions)
        }
        
        let target = Array(repeating: 0.0, count: numberOfPositions)
        let weights = Array(distances.lazy.map({ self.inverseSquareLaw(distance: $0) }))
        
        let optimum = solve(target: target, weights: weights, initialPoint: initialPoint)
        
        // Target values at optimal point in least square equation
        // (x0+xi)^2 + (y0+yi)^2 + ri^2 = target[i]
        do {
            let evaluation = try optimize(optium: optimum)
            return evaluation.point
        } catch {
            return [Double]()
        }
    }
    
    private func inverseSquareLaw(distance: Double) -> Double {
        return 1 / (distance * distance)
    }
    
    private func solve(target: [Double], weights: [Double], initialPoint: [Double]) -> Optimum {
        var optimun = Optimum()
        optimun.target = target
        optimun.weightSquareRoot = Array(weights.lazy.map({ sqrt($0) }))
        optimun.start = Array(initialPoint.lazy.map({ $0 }))
        
        return optimun
    }
    
    private func optimize(optium: Optimum) throws -> Evaluation {
        let initialStepBoundFactor = 100.0
        let orthoTolerance = 1.0e-10
        let costRelativeTolerance = 1.0e-10
        let parRelativeTolerance = 1.0e-10
        let two_eps = 2.220446049250313e-16
        
        // Pull in relevant data from the problem as locals
        let nR = optium.target.count // Number of observed data
        let nC = optium.start.count // Number of parameters
        var iterationCounter = 0
        var evaluationCounter = 1
        
        // Levenberg-Marquardt parameters
        let solvedCols = min(nR, nC)
        var lmPar = 0.0
        var lmDir = Array(repeating: 0.0, count: nC)
        
        // Local point
        var delta   = 0.0
        var xNorm   = 0.0
        var diag    = Array(repeating: 0.0, count: nC)
        var oldX    = Array(repeating: 0.0, count: nC)
        var oldRes  = Array(repeating: 0.0, count: nR)
        var qtf     = Array(repeating: 0.0, count: nR)
        var work1   = Array(repeating: 0.0, count: nC)
        var work2   = Array(repeating: 0.0, count: nC)
        var work3   = Array(repeating: 0.0, count: nC)
        
        // Evaluate the function at the starting point and calculate its norm
        var current = Evaluation(jacobian: jacobian(point: optium.start), residuals: value(point: optium.start), point: optium.start)
        var currentResiduals = getResiduals(residuals: current.residuals, weightSquareRoot: optium.weightSquareRoot)
        var currentCost = getCost(residuals: currentResiduals)
        var currentPoint = optium.start
        
        var firstIteration = true
        while true {
            iterationCounter += 1
            if iterationCounter > Optimum.maxIterations {
                throw LMAMathError.maxIterations
            }
            
            let previous = current
            
            // QR decomposition of the jacobian matrix
            var internalData = qrDecomposition(jacobian: current.jacobian, weightSquareRoot: optium.weightSquareRoot, solvedCols: solvedCols)
            var weightedJacobian = internalData.weightedJacobian
            let permutation = internalData.permutation
            let diagR = internalData.diagR
            let jacNorm = internalData.jacNorm
            
            // Residuals already have weights applied
            var weightedResidual = currentResiduals
            for i in 0..<nR {
                qtf[i] = weightedResidual[i]
            }
            
            // Compute Qt.res
            qTy(y: &qtf, internalData: internalData)
            
            // Now we don't need Q anymore,
            // So let jacobian contain the R matrix with its diagonal elements
            for k in 0..<solvedCols {
                let pk = permutation[k]
                weightedJacobian[k][pk] = diagR[pk]
            }
            internalData.weightedJacobian = weightedJacobian
            
            if (firstIteration) {
                // Scale the point according to the norms of the columns
                // Of the initial jacobian
                xNorm = 0
                for k in 0..<nC {
                    var dk = jacNorm[k]
                    if (dk == 0) {
                        dk = 1.0
                    }
                    let xk = dk * currentPoint[k]
                    xNorm  += xk * xk
                    diag[k] = dk
                }
                
                xNorm = sqrt(xNorm)
                // Initialize the step bound delta
                delta = (xNorm == 0) ? initialStepBoundFactor : (initialStepBoundFactor * xNorm)
            }
            
            // Check orthogonality between function vector and jacobian columns
            var maxCosine = 0.0
            if (currentCost != 0) {
                for j in 0..<solvedCols {
                    let pj = permutation[j]
                    let s = jacNorm[pj]
                    if (s != 0) {
                        var sum = 0.0
                        for i in 0...j {
                            sum += weightedJacobian[i][pj] * qtf[i]
                        }
                        maxCosine = max(maxCosine, abs(sum) / ( s * currentCost))
                    }
                }
            }
            
            if (maxCosine <= orthoTolerance) {
                // Convergence has been reached
                return current
            }
            
            // Rescale if necessary
            for j in 0..<nC {
                diag[j] = max(diag[j], jacNorm[j])
            }
            
            // Inner loop
            var ratio = 0.0
            while (ratio < 1.0e-4) {
                // Save the state
                for j in 0..<solvedCols {
                    let pj = permutation[j]
                    oldX[pj] = currentPoint[pj]
                }
                
                let previousCost = currentCost
                var tmpVec = weightedResidual
                weightedResidual = oldRes
                oldRes = tmpVec
                
                // Determine the Levenberg-Marquardt parameter
                lmPar = determineLMParameter(qy: qtf, delta: delta, diag: diag, internalData: internalData, solvedCols: solvedCols, work1: &work1, work2: &work2, work3: &work3, lmDir: &lmDir, lmPar: &lmPar)
                
                // Compute the new point and the norm of the evolution direction
                var lmNorm = 0.0
                for j in 0..<solvedCols {
                    let pj = permutation[j]
                    lmDir[pj] = -lmDir[pj]
                    currentPoint[pj] = oldX[pj] + lmDir[pj]
                    let s = diag[pj] * lmDir[pj]
                    lmNorm  += s * s
                }
                lmNorm = sqrt(lmNorm)
                // On the first iteration, adjust the initial step bound
                if (firstIteration) {
                    delta = min(delta, lmNorm)
                }
                
                // Evaluate the function at x + p and calculate its norm
                evaluationCounter += 1
                if evaluationCounter > Optimum.maxEvaluations {
                    throw LMAMathError.maxEvaluations
                }
                
                current = Evaluation(jacobian: jacobian(point: currentPoint), residuals: value(point: currentPoint), point: currentPoint)
                currentResiduals = getResiduals(residuals: current.residuals, weightSquareRoot: optium.weightSquareRoot)
                currentCost = getCost(residuals: currentResiduals)
                
                // Compute the scaled actual reduction
                var actRed = -1.0
                if (0.1 * currentCost < previousCost) {
                    let r = currentCost / previousCost
                    actRed = 1.0 - r * r
                }
                
                // Compute the scaled predicted reduction
                // and the scaled directional derivative
                for j in 0..<solvedCols {
                    let pj = permutation[j]
                    let dirJ = lmDir[pj]
                    work1[j] = 0
                    for i in 0...j {
                        work1[i] += weightedJacobian[i][pj] * dirJ
                    }
                }
                var coeff1 = 0.0
                for j in 0..<solvedCols {
                    coeff1 += work1[j] * work1[j]
                }
                let pc2 = previousCost * previousCost
                coeff1 /= pc2
                let coeff2 = lmPar * lmNorm * lmNorm / pc2
                let preRed = coeff1 + 2 * coeff2
                let dirDer = -(coeff1 + coeff2)
                
                // Ratio of the actual to the predicted reduction
                ratio = (preRed == 0) ? 0 : (actRed / preRed)
                
                // Update the step bound
                if (ratio <= 0.25) {
                    var tmp =
                        (actRed < 0) ? (0.5 * dirDer / (dirDer + 0.5 * actRed)) : 0.5
                    if ((0.1 * currentCost >= previousCost) || (tmp < 0.1)) {
                        tmp = 0.1
                    }
                    delta = tmp * min(delta, 10.0 * lmNorm)
                    lmPar /= tmp
                } else if ((lmPar == 0) || (ratio >= 0.75)) {
                    delta = 2 * lmNorm
                    lmPar *= 0.5
                }
                
                // Test for successful iteration
                if (ratio >= 1.0e-4) {
                    // Successful iteration, update the norm
                    firstIteration = false
                    xNorm = 0
                    for k in 0..<nC {
                        let xK = diag[k] * currentPoint[k]
                        xNorm += xK * xK
                    }
                    xNorm = sqrt(xNorm)
                } else {
                    // Failed iteration, reset the previous values
                    currentCost = previousCost
                    for j in 0..<solvedCols {
                        let pj = permutation[j]
                        currentPoint[pj] = oldX[pj]
                    }
                    tmpVec = weightedResidual
                    weightedResidual = oldRes
                    oldRes = tmpVec
                    // Reset "current" to previous values
                    current = previous
                }
                
                // Default convergence criteria
                if ((abs(actRed) <= costRelativeTolerance &&
                        preRed <= costRelativeTolerance &&
                        ratio <= 2.0) ||
                        delta <= parRelativeTolerance * xNorm) {
                    return current
                }
                
                // Tests for termination and stringent tolerances
                if (abs(actRed) <= two_eps &&
                        preRed <= two_eps &&
                        ratio <= 2.0) {
                    throw LMAMathError.costRelativeTolerance
                } else if (delta <= two_eps * xNorm) {
                    throw LMAMathError.parRelativeTolerance
                } else if (maxCosine <= two_eps) {
                    throw LMAMathError.orthoTolerance
                }
            }
        }
    }
    
    private func jacobian(point: [Double]) -> [[Double]] {
        var jacobian = Array(repeating: Array(repeating: 0.0, count: point.count), count: distances.count)
        for i in 0..<jacobian.count {
            for j in 0..<point.count {
                jacobian[i][j] = 2 * point[j] - 2 * positions[i][j]
            }
        }
        
        return jacobian
    }
    
    private func value(point: [Double]) -> [Double] {
        var resultPoint = Array(repeating: 0.0, count: distances.count)
        
        // Compute least squares
        for i in 0..<resultPoint.count {
            resultPoint[i] = 0.0
            
            // Calculate sum, add to overall
            for j in 0..<point.count {
                resultPoint[i] += (point[j] - positions[i][j]) * (point[j] - positions[i][j])
            }
            
            resultPoint[i] -= distances[i] * distances[i]
            resultPoint[i] *= -1
        }
        
        return resultPoint
    }
    
    private func getResiduals(residuals: [Double], weightSquareRoot: [Double]) -> [Double] {
        var resultResiduals = Array(repeating: 0.0, count: residuals.count)
        for i in 0..<residuals.count {
            resultResiduals[i] = residuals[i] * weightSquareRoot[i]
        }
        
        return resultResiduals
    }
    
    private func getCost(residuals: [Double]) -> Double {
        let dot = Array(residuals.lazy.map({ $0 * $0 })).reduce(0, +)
        return sqrt(dot)
    }
    
    private func qrDecomposition(jacobian: [[Double]], weightSquareRoot: [Double], solvedCols: Int) -> InternalData {
        // Code in this function assumes that the weighted Jacobian is -(W^(1/2) J), hence the multiplication by -1
        
        var weightedJacobian = jacobian
        for (index, value) in jacobian.enumerated() {
            // Scalar multiply to -1
            weightedJacobian[index] = Array(value.lazy.map({ $0 * (-weightSquareRoot[index])}))
        }
        
        let nR = weightedJacobian.count
        let nC = weightedJacobian[0].count
        
        var permutation = Array(repeating: 0, count: nC)
        var diagR = Array(repeating: 0.0, count: nC)
        var jacNorm = Array(repeating: 0.0, count: nC)
        var beta = Array(repeating: 0.0, count: nC)
        
        // Initializations
        for k in 0..<nC {
            permutation[k] = k
            var norm2 = 0.0
            for i in 0..<nR {
                let akk = weightedJacobian[i][k]
                norm2 += akk * akk
            }
            jacNorm[k] = sqrt(norm2)
        }
        
        // Transform the matrix column after column
        for k in 0..<nC {
            // Select the column with the greatest norm on active components
            var nextColumn = -1
            var ak2 = -Double.infinity
            for i in k..<nC {
                var norm2 = 0.0
                for j in k..<nR {
                    let aki = weightedJacobian[j][permutation[i]]
                    norm2 += aki * aki
                }
                
                if (norm2 > ak2) {
                    nextColumn = i
                    ak2 = norm2
                }
            }
            
            guard nextColumn != -1 else { break }
            let pk = permutation[nextColumn]
            permutation[nextColumn] = permutation[k]
            permutation[k] = pk
            
            // Choose alpha such that Hk.u = alpha ek
            let akk = weightedJacobian[k][pk]
            let alpha = (akk > 0) ? -sqrt(ak2) : sqrt(ak2)
            let betak = 1.0 / (ak2 - akk * alpha)
            beta[pk] = betak
            
            // Transform the current column
            diagR[pk] = alpha
            weightedJacobian[k][pk] -= alpha
            
            for dk in stride(from: nC - 1 - k, to: 0, by: -1) {
                var gamma = 0.0
                for j in k..<nR {
                    gamma += weightedJacobian[j][pk] * weightedJacobian[j][permutation[k + dk]]
                }
                gamma *= betak
                for j in k..<nR {
                    weightedJacobian[j][permutation[k + dk]] -= gamma * weightedJacobian[j][pk]
                }
            }
        }
        
        return InternalData(weightedJacobian: weightedJacobian, permutation: permutation, rank: solvedCols, diagR: diagR, jacNorm: jacNorm, beta: beta)
    }
    
    private func qTy(y: inout [Double], internalData: InternalData) {
        let weightedJacobian = internalData.weightedJacobian
        let permutation = internalData.permutation
        let beta = internalData.beta
        
        let nR = weightedJacobian.count
        let nC = weightedJacobian[0].count
        
        for k in 0..<nC {
            let pk = permutation[k]
            var gamma = 0.0
            
            for i in k..<nR {
                gamma += weightedJacobian[i][pk] * y[i]
            }
            gamma *= beta[pk]
            for i in k..<nR {
                y[i] -= gamma * weightedJacobian[i][pk]
            }
        }
    }
    
    private func determineLMParameter(qy: [Double], delta: Double, diag: [Double],
                                      internalData: InternalData, solvedCols: Int,
                                      work1: inout [Double], work2: inout [Double],
                                      work3: inout [Double], lmDir: inout [Double],
                                      lmPar: inout Double) -> Double {
        let safeMin = 2.2250738585072014e-308
        let weightedJacobian = internalData.weightedJacobian
        let permutation = internalData.permutation
        let rank = internalData.rank
        let diagR = internalData.diagR
        
        let nC = weightedJacobian[0].count
        
        // Compute and store in x the gauss-newton direction, if the
        // jacobian is rank-deficient, obtain a least squares solution
        for j in 0..<rank {
            lmDir[permutation[j]] = qy[j]
        }
        for j in rank..<nC {
            lmDir[permutation[j]] = 0
        }
        for k in stride(from: rank - 1, through: 0, by: -1) {
            let pk = permutation[k]
            let ypk = lmDir[pk] / diagR[pk]
            for i in 0..<k {
                lmDir[permutation[i]] -= ypk * weightedJacobian[i][pk]
            }
            lmDir[pk] = ypk
        }
        
        // Evaluate the function at the origin, and test
        // for acceptance of the Gauss-Newton direction
        var dxNorm = 0.0
        for j in 0..<solvedCols {
            let pj = permutation[j]
            let s = diag[pj] * lmDir[pj]
            work1[pj] = s
            dxNorm += s * s
        }
        
        dxNorm = sqrt(dxNorm)
        var fp = dxNorm - delta
        if (fp <= 0.1 * delta) {
            lmPar = 0
            return lmPar
        }
        
        // If the jacobian is not rank deficient, the Newton step provides
        // a lower bound, parl, for the zero of the function,
        // otherwise set this bound to zero
        var sum2 = 0.0
        var parl = 0.0
        if (rank == solvedCols) {
            for j in 0..<solvedCols {
                let pj = permutation[j]
                work1[pj] *= diag[pj] / dxNorm
            }
            sum2 = 0.0
            for j in 0..<solvedCols {
                let pj = permutation[j]
                var sum = 0.0
                for i in 0..<j {
                    sum += weightedJacobian[i][pj] * work1[permutation[i]]
                }
                let s = (work1[pj] - sum) / diagR[pj]
                work1[pj] = s
                sum2 += s * s
            }
            parl = fp / (delta * sum2)
        }
        
        // Calculate an upper bound, paru, for the zero of the function
        sum2 = 0.0
        for j in 0..<solvedCols {
            let pj = permutation[j]
            var sum = 0.0
            for i in 0...j {
                sum += weightedJacobian[i][pj] * qy[i]
            }
            sum /= diag[pj]
            sum2 += sum * sum
        }
        let gNorm = sqrt(sum2)
        var paru = gNorm / delta
        if (paru == 0) {
            paru = safeMin / min(delta, 0.1)
        }
        
        // If the input par lies outside of the interval (parl,paru),
        // set par to the closer endpoint
        lmPar = min(paru, max(lmPar, parl))
        if (lmPar == 0) {
            lmPar = gNorm / dxNorm
        }
        
        for _ in stride(from: 10, through: 0, by: -1) {
            
            // Evaluate the function at the current value of lmPar
            if (lmPar == 0) {
                lmPar = max(safeMin, 0.001 * paru)
            }
            let sPar = sqrt(lmPar)
            for j in 0..<solvedCols {
                let pj = permutation[j]
                work1[pj] = sPar * diag[pj]
            }
            determineLMDirection(qy: qy, diag: work1, lmDiag: &work2, internalData: internalData, solvedCols: solvedCols, work: &work3, lmDir: &lmDir)
            
            dxNorm = 0.0
            for j in 0..<solvedCols {
                let pj = permutation[j]
                let s = diag[pj] * lmDir[pj]
                work3[pj] = s
                dxNorm += s * s
            }
            dxNorm = sqrt(dxNorm)
            let previousFP = fp
            fp = dxNorm - delta
            
            // If the function is small enough, accept the current value
            // of lmPar, also test for the exceptional cases where parl is zero
            if (abs(fp) <= 0.1 * delta ||
                    (parl == 0 &&
                        fp <= previousFP &&
                        previousFP < 0)) {
                return lmPar
            }
            
            // Compute the Newton correction
            for j in 0..<solvedCols {
                let pj = permutation[j]
                work1[pj] = work3[pj] * diag[pj] / dxNorm
            }
            for j in 0..<solvedCols {
                let pj = permutation[j]
                work1[pj] /= work2[j]
                let tmp = work1[pj]
                for i in j + 1..<solvedCols {
                    work1[permutation[i]] -= weightedJacobian[i][pj] * tmp
                }
            }
            sum2 = 0.0
            for j in 0..<solvedCols {
                let s = work1[permutation[j]]
                sum2 += s * s
            }
            let correction = fp / (delta * sum2)
            
            // Depending on the sign of the function, update parl or paru
            if (fp > 0) {
                parl = max(parl, lmPar)
            } else if (fp < 0) {
                paru = min(paru, lmPar)
            }
            
            // Compute an improved estimate for lmPar
            lmPar = max(parl, lmPar + correction)
        }
        
        return lmPar
    }
    
    private func determineLMDirection(qy: [Double], diag: [Double], lmDiag: inout [Double],
                                      internalData: InternalData, solvedCols: Int,
                                      work: inout [Double], lmDir: inout [Double]) {
        let permutation = internalData.permutation
        var weightedJacobian = internalData.weightedJacobian
        let diagR = internalData.diagR
        
        // Copy R and Qty to preserve input and initialize s
        // in particular, save the diagonal elements of R in lmDir
        for j in 0..<solvedCols {
            let pj = permutation[j]
            for i in j + 1..<solvedCols {
                weightedJacobian[i][pj] = weightedJacobian[j][permutation[i]]
            }
            lmDir[j] = diagR[pj]
            work[j]  = qy[j]
        }
        
        // Eliminate the diagonal matrix d using a Givens rotation
        for j in 0..<solvedCols {
            
            // Prepare the row of d to be eliminated, locating the
            // diagonal element using p from the Q.R. factorization
            let pj = permutation[j]
            let dpj = diag[pj]
            if (dpj != 0) {
                for k in j + 1..<lmDiag.count {
                    lmDiag[k] = 0
                }
            }
            lmDiag[j] = dpj
            
            // The transformations to eliminate the row of d
            // modify only a single element of Qty
            // beyond the first n, which is initially zero.
            var qtbpj = 0.0
            for k in j..<solvedCols {
                let pk = permutation[k]
                
                // Determine a Givens rotation which eliminates the
                // appropriate element in the current row of d
                if (lmDiag[k] != 0) {
                    
                    var sin = 0.0
                    var cos = 0.0
                    let rkk = weightedJacobian[k][pk]
                    if (abs(rkk) < abs(lmDiag[k])) {
                        let cotan = rkk / lmDiag[k]
                        sin = 1.0 / sqrt(1.0 + cotan * cotan)
                        cos = sin * cotan
                    } else {
                        let tan = lmDiag[k] / rkk
                        cos = 1.0 / sqrt(1.0 + tan * tan)
                        sin = cos * tan
                    }
                    
                    // Compute the modified diagonal element of R and
                    // the modified element of (Qty,0)
                    weightedJacobian[k][pk] = cos * rkk + sin * lmDiag[k]
                    let temp = cos * work[k] + sin * qtbpj
                    qtbpj = -sin * work[k] + cos * qtbpj
                    work[k] = temp
                    
                    // Accumulate the tranformation in the row of s
                    for i in k + 1..<solvedCols {
                        let rik = weightedJacobian[i][pk]
                        let temp2 = cos * rik + sin * lmDiag[i]
                        lmDiag[i] = -sin * rik + cos * lmDiag[i]
                        weightedJacobian[i][pk] = temp2
                    }
                }
            }
            
            // Store the diagonal element of s and restore
            // the corresponding diagonal element of R
            lmDiag[j] = weightedJacobian[j][permutation[j]]
            weightedJacobian[j][permutation[j]] = lmDir[j]
        }
        
        // Solve the triangular system for z, if the system is
        // singular, then obtain a least squares solution
        var nSing = solvedCols
        for j in 0..<solvedCols {
            if ((lmDiag[j] == 0) && (nSing == solvedCols)) {
                nSing = j
            }
            if (nSing < solvedCols) {
                work[j] = 0
            }
        }
        if (nSing > 0) {
            for j in stride(from: nSing - 1, through: 0, by: -1) {
                let pj = permutation[j]
                var sum = 0.0
                for i in j + 1..<nSing {
                    sum += weightedJacobian[i][pj] * work[i]
                }
                work[j] = (work[j] - sum) / lmDiag[j]
            }
        }
        
        // Permute the components of z back to components of lmDir
        for j in 0..<lmDir.count {
            lmDir[permutation[j]] = work[j]
        }
    }
}
