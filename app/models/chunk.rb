class Chunk < ApplicationRecord
  has_neighbors :embedding
end
