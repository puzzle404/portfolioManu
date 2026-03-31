class DolarService
  OFICIAL_URL = "https://dolarapi.com/v1/dolares/oficial"
  CACHE_KEY = "dolar_oficial_venta"
  CACHE_TTL = 1.hour

  def self.venta
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      fetch_from_api
    end
  end

  def self.fetch_from_api
    response = Net::HTTP.get(URI(OFICIAL_URL))
    data = JSON.parse(response)
    data["venta"].to_f
  rescue StandardError => e
    Rails.logger.error("DolarService error: #{e.message}")
    nil
  end
end
