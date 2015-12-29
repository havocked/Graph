
//Calculate new availableDSCR when adding or removing a Product in the graph
extension Graph: SimulatorDelegate {
    
    func didAddProduct(product: Product?) {
        
        let pmt = tmpAvailableDSCR * Float(product!.weight) / Float(simulation!.productList.allWeights())
        
        product?.pmt = Double(pmt)
        product?.updatePV()
        
        if product?.amount.observable.value < product?.amount.maximum {
            product?.amount.maximum = product!.amount.observable.value
        }
        
        
        addViewForProduct(product)
        update(animation: true)
    }
    
    func didRemoveProduct(product: Product?) {
        deleteViewForProduct(product)
        tmpAvailableDSCR = simulation!.applicant!.maximumDSCR - simulation!.sumPMT()
        self.availableDSCRLabel.text = "Available DSCR: \(self.tmpAvailableDSCR.formatToCurrency()) Rs"
        update(animation: true)
    }
}


//When user slides the value of slider for specific product
func didValueChanged(slider: CustomSlider) {
    
    //Every slider is linked with a specified product
    if let productChanged = slider.product {
        
        /****************/
        /** Begin calc **/
        /****************/
       
        productChanged.updatePMT()
        updateAvailableDSCR(productChanged)
        
        if tmpAvailableDSCR <= 0 {
            tmpAvailableDSCR = 0
            //Previous go previous pv and then stop
            productChanged.amount.observable.next(Double(slider.previousValue))
            //Should stop here !
            return
        } else {
            slider.previousValue = Float(productChanged.amount.observable.value)
        }
        
        self.availableDSCRLabel.text = "Available DSCR: \(self.tmpAvailableDSCR.formatToCurrency()) Rs"
        
        updateOtherProducts(except: productChanged)
        
        /****************/
        /*** End calc ***/
        /****************/
        updateSliderShape()
    }
}

func updateAvailableDSCR(productChanged: Product) {
    let allPMT = Float(simulation!.productList.totalPMT(except: productChanged))
    tmpAvailableDSCR = simulation!.applicant!.maximumDSCR - Float(allPMT) - Float(productChanged.pmt)
}


func updateOtherProducts(except productChanged: Product) {
    
    //Create a new array of product filtering the one that is just being modified (productChanged)
    if let filteredArray = simulation?.productList.filter({ $0 != productChanged }) {
        
        let weights = filteredArray.allWeights()
        
        for (_, product) in filteredArray.enumerate() {
            if !product.locked  {
                
                //Update new PMT for each products
                product.pmt = (Double(product.weight) * Double(tmpAvailableDSCR)) / Double(weights)
                //Then update the PV -> which is the value of slider
                product.updatePV()
            }
        }
    }
}


//Those methods are extension of Array of Product objects
extension CollectionType where Generator.Element == Product {
    
    func allWeights() -> Int {
        var sum = 0
        for element in self {
            sum += element.weight
        }
        return sum
    }

    func totalPMT(except except: Product) -> Double {
        var sum: Double = 0
        for element in self.filter({ $0 != except }) {
            sum += element.pmt
            print("pmt: \(element.pmt)")
        }
        return sum
    }

    func totalPV() -> Double {
        var sum: Double = 0
        for element in self {
            sum += element.amount.observable.value
        }
        return sum
    }
}

/*      NOTE: Extreme Type is like this:
*
*       class Extreme<T: NumericType> {
*           var observable: Observable<T> // Consider Observable like a regular type such as Int or Float/Double
*           var minimum: T
*           var maximum: T
*       }
*/

class Product {
    
    var id: String?
    var name: String?
    var amount:Extreme<Double>
    var interestRate: Extreme<Double>
    var duration: Extreme<Int>
    var weight: Int
    
    var locked: Bool
    
    var pmt: Double
    
    func updatePMT() {
        self.pmt = -1 * calcPMT(self.interestRate.observable.value / 12, n: Double(self.duration.observable.value * 12), p: self.amount.observable.value, f: 0, t: false)
    }
    
    func calcPMT(r: Double, n: Double, p: Double, f: Double, t: Bool) -> Double {
        var retval: Double = 0;
        if (r == 0) {
            retval = -1 * (f + p) / n;
        } else {
            let r1 = r + 1;
            retval = (f + p * pow(r1, n)) * r / ((t ? r1 : 1) * (1 - pow(r1, n)));
        }
        return retval;
    }
    
    func updatePV() {
        
        let newPV = calcPV((self.interestRate.observable.value / 100) / 12, n: Double(self.duration.observable.value * 12), y: self.pmt, f: 0, t: false)
        
        if newPV < self.amount.minimum {
            self.amount.observable.next(self.amount.minimum)
        }
    }
    
    func calcPV(r: Double, n: Double, y: Double, f: Double, t: Bool) -> Double {
        var retval = 0.0;
        let r1 = r + 1;
        retval = (((1 - pow(r1, -n)) / r) * y)
        return retval;
    }
}
